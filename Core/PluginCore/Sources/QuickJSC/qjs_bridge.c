#include "qjs_bridge.h"
#include "quickjs.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct QJSContextHandle {
    JSRuntime *runtime;
    JSContext *context;
    unsigned int timeout_ms;
    void *opaque;
    QJSLogCallback log_callback;
    QJSURLRequestCallback url_request_callback;
    uint64_t execution_started_ms;
    uint64_t execution_deadline_ms;
} QJSContextHandle;

static char *qjs_copy_bytes(const char *value, size_t length) {
    char *copy = malloc(length + 1);
    if (!copy) {
        return NULL;
    }
    memcpy(copy, value, length);
    copy[length] = '\0';
    return copy;
}

char *qjs_copy_string(const char *value) {
    if (!value) {
        return qjs_copy_bytes("", 0);
    }
    return qjs_copy_bytes(value, strlen(value));
}

void qjs_free_string(char *value) {
    free(value);
}

void *qjs_get_user_opaque(void *raw_handle) {
    QJSContextHandle *handle = raw_handle;
    return handle ? handle->opaque : NULL;
}

void qjs_set_user_opaque(void *raw_handle, void *opaque) {
    QJSContextHandle *handle = raw_handle;
    if (handle) {
        handle->opaque = opaque;
    }
}

static char *qjs_value_to_string(JSContext *context, JSValue value) {
    const char *text = JS_ToCString(context, value);
    if (!text) {
        return qjs_copy_string("Unknown JavaScript error");
    }
    char *copy = qjs_copy_string(text);
    JS_FreeCString(context, text);
    return copy;
}

static char *qjs_exception_message(JSContext *context, const char *prefix) {
    JSValue exception = JS_GetException(context);
    char *message = NULL;
    JSValue name = JS_GetPropertyStr(context, exception, "name");
    JSValue detail = JS_GetPropertyStr(context, exception, "message");
    JSValue stack = JS_GetPropertyStr(context, exception, "stack");
    char *name_text = qjs_value_to_string(context, name);
    char *detail_text = qjs_value_to_string(context, detail);
    char *stack_text = qjs_value_to_string(context, stack);

    const char *safe_prefix = prefix ? prefix : "JavaScript error";
    const char *safe_name = name_text ? name_text : "Error";
    const char *safe_detail = detail_text ? detail_text : "";
    const char *safe_stack = stack_text ? stack_text : "";
    int length = snprintf(NULL, 0, "%s: %s: %s%s%s", safe_prefix, safe_name,
                          safe_detail, safe_stack[0] ? "\n" : "", safe_stack);
    if (length >= 0) {
        message = malloc((size_t)length + 1);
        if (message) {
            snprintf(message, (size_t)length + 1, "%s: %s: %s%s%s", safe_prefix,
                     safe_name, safe_detail, safe_stack[0] ? "\n" : "", safe_stack);
        }
    }

    JS_FreeValue(context, name);
    JS_FreeValue(context, detail);
    JS_FreeValue(context, stack);
    JS_FreeValue(context, exception);
    free(name_text);
    free(detail_text);
    free(stack_text);
    return message ? message : qjs_copy_string("JavaScript error");
}

static int qjs_set_exception_error(JSContext *context, char **error_message, const char *prefix) {
    if (error_message) {
        *error_message = qjs_exception_message(context, prefix);
    } else {
        JSValue exception = JS_GetException(context);
        JS_FreeValue(context, exception);
    }
    return -1;
}

static int qjs_set_error(char **error_message, const char *message) {
    if (error_message) {
        *error_message = qjs_copy_string(message);
    }
    return -1;
}

static char *qjs_json_stringify(JSContext *context, JSValue value) {
    JSValue json = JS_JSONStringify(context, value, JS_UNDEFINED, JS_UNDEFINED);
    if (JS_IsException(json) || JS_IsUndefined(json)) {
        if (JS_IsException(json)) {
            JS_FreeValue(context, json);
        }
        return NULL;
    }
    char *result = qjs_value_to_string(context, json);
    JS_FreeValue(context, json);
    return result;
}

static int qjs_arguments(JSContext *context, const char *arguments_json,
                         JSValue **arguments, uint32_t *count, char **error_message) {
    JSValue array = JS_ParseJSON(context, arguments_json, strlen(arguments_json), "<arguments>");
    if (JS_IsException(array)) {
        return qjs_set_exception_error(context, error_message, "Argument serialization error");
    }
    if (!JS_IsArray(context, array)) {
        JS_FreeValue(context, array);
        return qjs_set_error(error_message, "Argument serialization error: expected an array");
    }

    JSValue length_value = JS_GetPropertyStr(context, array, "length");
    uint32_t length = 0;
    if (JS_ToUint32(context, &length, length_value) < 0) {
        JS_FreeValue(context, length_value);
        JS_FreeValue(context, array);
        return qjs_set_exception_error(context, error_message, "Argument serialization error");
    }
    JS_FreeValue(context, length_value);

    JSValue *values = NULL;
    if (length > 0) {
        values = calloc(length, sizeof(JSValue));
        if (!values) {
            JS_FreeValue(context, array);
            return qjs_set_error(error_message, "Argument serialization error: out of memory");
        }
    }
    for (uint32_t index = 0; index < length; index++) {
        values[index] = JS_GetPropertyUint32(context, array, index);
        if (JS_IsException(values[index])) {
            for (uint32_t cleanup = 0; cleanup < index; cleanup++) {
                JS_FreeValue(context, values[cleanup]);
            }
            free(values);
            JS_FreeValue(context, array);
            return qjs_set_exception_error(context, error_message, "Argument serialization error");
        }
    }
    JS_FreeValue(context, array);
    *arguments = values;
    *count = length;
    return 0;
}

static void qjs_free_arguments(JSContext *context, JSValue *arguments, uint32_t count) {
    for (uint32_t index = 0; index < count; index++) {
        JS_FreeValue(context, arguments[index]);
    }
    free(arguments);
}

static int qjs_call(JSContext *context, const char *function_name,
                    const char *arguments_json, JSValue *result,
                    char **error_message) {
    JSValue global = JS_GetGlobalObject(context);
    JSValue function = JS_GetPropertyStr(context, global, function_name);
    JS_FreeValue(context, global);
    if (JS_IsException(function)) {
        return qjs_set_exception_error(context, error_message, "Function lookup failed");
    }
    if (!JS_IsFunction(context, function)) {
        JS_FreeValue(context, function);
        return qjs_set_error(error_message, "Function not found");
    }

    JSValue *arguments = NULL;
    uint32_t count = 0;
    if (qjs_arguments(context, arguments_json, &arguments, &count, error_message) < 0) {
        JS_FreeValue(context, function);
        return -1;
    }

    JSValue call_result = JS_Call(context, function, JS_UNDEFINED, (int)count, arguments);
    qjs_free_arguments(context, arguments, count);
    JS_FreeValue(context, function);
    if (JS_IsException(call_result)) {
        return qjs_set_exception_error(context, error_message, "Function call failed");
    }
    *result = call_result;
    return 0;
}

static uint64_t qjs_now_milliseconds(void) {
    struct timespec time;
    clock_gettime(CLOCK_MONOTONIC, &time);
    return (uint64_t)time.tv_sec * 1000 + (uint64_t)time.tv_nsec / 1000000;
}

static int qjs_interrupt_handler(JSRuntime *runtime, void *opaque) {
    (void)runtime;
    QJSContextHandle *handle = opaque;
    if (!handle || handle->execution_deadline_ms == 0) {
        return 0;
    }
    return qjs_now_milliseconds() >= handle->execution_deadline_ms;
}

static JSValue qjs_log(JSContext *context, JSValueConst this_value, int argc, JSValueConst *argv) {
    (void)this_value;
    QJSContextHandle *handle = JS_GetRuntimeOpaque(JS_GetRuntime(context));
    if (!handle || argc != 2 || !handle->log_callback) {
        return JS_ThrowTypeError(context, "util.log expects message and severity");
    }
    const char *message = JS_ToCString(context, argv[0]);
    const char *severity = JS_ToCString(context, argv[1]);
    if (!message || !severity) {
        JS_FreeCString(context, message);
        JS_FreeCString(context, severity);
        return JS_ThrowTypeError(context, "util.log arguments must be strings");
    }
    handle->log_callback(handle->opaque, message, severity);
    JS_FreeCString(context, message);
    JS_FreeCString(context, severity);
    return JS_UNDEFINED;
}

static JSValue qjs_url_request(JSContext *context, JSValueConst this_value, int argc, JSValueConst *argv) {
    (void)this_value;
    QJSContextHandle *handle = JS_GetRuntimeOpaque(JS_GetRuntime(context));
    if (!handle || argc != 4 || !handle->url_request_callback) {
        return JS_ThrowTypeError(context, "util.urlRequest expects url, headers, method and body");
    }

    const char *values[4] = { NULL, NULL, NULL, NULL };
    for (int index = 0; index < 4; index++) {
        values[index] = JS_ToCString(context, argv[index]);
        if (!values[index]) {
            for (int cleanup = 0; cleanup <= index; cleanup++) {
                JS_FreeCString(context, values[cleanup]);
            }
            return JS_ThrowTypeError(context, "util.urlRequest arguments must be strings");
        }
    }

    char *body_json = NULL;
    char *headers_json = NULL;
    char *error_message = NULL;
    int callback_result = handle->url_request_callback(handle->opaque, values[0], values[1],
                                                       values[2], values[3], &body_json,
                                                       &headers_json, &error_message);
    for (int index = 0; index < 4; index++) {
        JS_FreeCString(context, values[index]);
    }
    if (callback_result != 0) {
        JSValue error = JS_ThrowInternalError(context, "%s", error_message ? error_message : "urlRequest failed");
        qjs_free_string(body_json);
        qjs_free_string(headers_json);
        qjs_free_string(error_message);
        return error;
    }

    JSValue response = JS_NewObject(context);
    JSValue body = JS_ParseJSON(context, body_json ? body_json : "{}", strlen(body_json ? body_json : "{}"), "<urlRequest.body>");
    JSValue headers = JS_ParseJSON(context, headers_json ? headers_json : "{}", strlen(headers_json ? headers_json : "{}"), "<urlRequest.headers>");
    JSValue error = JS_NewString(context, error_message ? error_message : "");
    qjs_free_string(body_json);
    qjs_free_string(headers_json);
    qjs_free_string(error_message);
    if (JS_IsException(body) || JS_IsException(headers)) {
        JS_FreeValue(context, response);
        JS_FreeValue(context, body);
        JS_FreeValue(context, headers);
        JS_FreeValue(context, error);
        return JS_ThrowTypeError(context, "util.urlRequest returned malformed JSON");
    }
    JS_SetPropertyStr(context, response, "body", body);
    JS_SetPropertyStr(context, response, "headers", headers);
    JS_SetPropertyStr(context, response, "error", error);
    return response;
}

void *qjs_context_new(size_t memory_limit, size_t stack_limit, unsigned int timeout_ms) {
    QJSContextHandle *handle = calloc(1, sizeof(QJSContextHandle));
    if (!handle) {
        return NULL;
    }
    handle->runtime = JS_NewRuntime();
    if (!handle->runtime) {
        free(handle);
        return NULL;
    }
    handle->context = JS_NewContext(handle->runtime);
    if (!handle->context) {
        JS_FreeRuntime(handle->runtime);
        free(handle);
        return NULL;
    }
    handle->timeout_ms = timeout_ms;
    JS_SetRuntimeOpaque(handle->runtime, handle);
    JS_SetMemoryLimit(handle->runtime, memory_limit);
    JS_SetMaxStackSize(handle->runtime, stack_limit);
    JS_SetInterruptHandler(handle->runtime, qjs_interrupt_handler, handle);
    return handle;
}

void qjs_context_free(void *raw_handle) {
    QJSContextHandle *handle = raw_handle;
    if (!handle) {
        return;
    }
    JS_FreeContext(handle->context);
    JS_FreeRuntime(handle->runtime);
    free(handle);
}

void qjs_context_reset(void *raw_handle) {
    QJSContextHandle *handle = raw_handle;
    if (!handle) {
        return;
    }
    JSContext *context = JS_NewContext(handle->runtime);
    if (!context) {
        return;
    }
    JS_FreeContext(handle->context);
    handle->context = context;
    JS_SetRuntimeOpaque(handle->runtime, handle);
}

int qjs_evaluate(void *raw_handle, const char *source, const char *filename, char **error_message) {
    QJSContextHandle *handle = raw_handle;
    if (!handle || !source) {
        return qjs_set_error(error_message, "Runtime is not available");
    }
    handle->execution_started_ms = qjs_now_milliseconds();
    handle->execution_deadline_ms = handle->timeout_ms == 0
        ? 0
        : handle->execution_started_ms + handle->timeout_ms;
    JSValue result = JS_Eval(handle->context, source, strlen(source), filename ? filename : "<plugin>", JS_EVAL_TYPE_GLOBAL);
    handle->execution_started_ms = 0;
    handle->execution_deadline_ms = 0;
    if (JS_IsException(result)) {
        return qjs_set_exception_error(handle->context, error_message, "JavaScript evaluation failed");
    }
    JS_FreeValue(handle->context, result);
    return 0;
}

int qjs_call_json(void *raw_handle, const char *function_name,
                  const char *arguments_json, char **result_json, char **error_message) {
    QJSContextHandle *handle = raw_handle;
    if (!handle || !function_name || !arguments_json) {
        return qjs_set_error(error_message, "Invalid JavaScript call");
    }
    handle->execution_started_ms = qjs_now_milliseconds();
    handle->execution_deadline_ms = handle->timeout_ms == 0
        ? 0
        : handle->execution_started_ms + handle->timeout_ms;
    JSValue result;
    if (qjs_call(handle->context, function_name, arguments_json, &result, error_message) < 0) {
        handle->execution_started_ms = 0;
        handle->execution_deadline_ms = 0;
        return -1;
    }
    handle->execution_started_ms = 0;
    handle->execution_deadline_ms = 0;
    char *json = qjs_json_stringify(handle->context, result);
    JS_FreeValue(handle->context, result);
    if (!json) {
        if (JS_HasException(handle->context)) {
            return qjs_set_exception_error(handle->context, error_message, "Result serialization failed");
        }
        return qjs_set_error(error_message, "Result serialization failed");
    }
    *result_json = json;
    return 0;
}

int qjs_call_async_json(void *raw_handle, const char *function_name,
                        const char *arguments_json, unsigned int timeout_ms,
                        unsigned int max_jobs, char **result_json, char **error_message) {
    QJSContextHandle *handle = raw_handle;
    if (!handle) {
        return qjs_set_error(error_message, "Runtime is not available");
    }
    uint64_t started = qjs_now_milliseconds();
    handle->execution_started_ms = started;
    handle->execution_deadline_ms = timeout_ms == 0 ? 0 : started + timeout_ms;
    JSValue result;
    if (qjs_call(handle->context, function_name, arguments_json, &result, error_message) < 0) {
        handle->execution_started_ms = 0;
        handle->execution_deadline_ms = 0;
        return -1;
    }
    if (JS_PromiseState(handle->context, result) == -1) {
        char *json = qjs_json_stringify(handle->context, result);
        handle->execution_started_ms = 0;
        handle->execution_deadline_ms = 0;
        JS_FreeValue(handle->context, result);
        if (!json) {
            return qjs_set_error(error_message, "Async result serialization failed");
        }
        *result_json = json;
        return 0;
    }

    unsigned int jobs = 0;
    while (JS_PromiseState(handle->context, result) == JS_PROMISE_PENDING) {
        if (timeout_ms != 0 && qjs_now_milliseconds() - started >= timeout_ms) {
            handle->execution_started_ms = 0;
            handle->execution_deadline_ms = 0;
            JS_FreeValue(handle->context, result);
            return qjs_set_error(error_message, "JavaScript promise timed out");
        }
        if (jobs++ >= max_jobs) {
            handle->execution_started_ms = 0;
            handle->execution_deadline_ms = 0;
            JS_FreeValue(handle->context, result);
            return qjs_set_error(error_message, "JavaScript promise exceeded job limit");
        }
        JSContext *job_context = NULL;
        handle->execution_started_ms = qjs_now_milliseconds();
        int job_result = JS_ExecutePendingJob(handle->runtime, &job_context);
        if (job_result < 0) {
            handle->execution_started_ms = 0;
            handle->execution_deadline_ms = 0;
            JS_FreeValue(handle->context, result);
            return qjs_set_exception_error(job_context ? job_context : handle->context,
                                           error_message, "Promise job failed");
        }
        if (job_result == 0) {
            handle->execution_started_ms = 0;
            handle->execution_deadline_ms = 0;
            JS_FreeValue(handle->context, result);
            return qjs_set_error(error_message, "JavaScript promise timed out");
        }
    }

    JSValue promise_result = JS_PromiseResult(handle->context, result);
    JSPromiseStateEnum state = JS_PromiseState(handle->context, result);
    JS_FreeValue(handle->context, result);
    if (state == JS_PROMISE_REJECTED) {
        char *message = qjs_value_to_string(handle->context, promise_result);
        JS_FreeValue(handle->context, promise_result);
        if (error_message) {
            int length = snprintf(NULL, 0, "Promise rejected: %s", message ? message : "Unknown error");
            *error_message = malloc((size_t)length + 1);
            if (*error_message) {
                snprintf(*error_message, (size_t)length + 1, "Promise rejected: %s", message ? message : "Unknown error");
            }
        }
        free(message);
        handle->execution_started_ms = 0;
        handle->execution_deadline_ms = 0;
        return -1;
    }
    char *json = qjs_json_stringify(handle->context, promise_result);
    handle->execution_started_ms = 0;
    handle->execution_deadline_ms = 0;
    JS_FreeValue(handle->context, promise_result);
    if (!json) {
        return qjs_set_error(error_message, "Async result serialization failed");
    }
    *result_json = json;
    return 0;
}

int qjs_get_global_json(void *raw_handle, const char *key,
                        char **result_json, char **error_message) {
    QJSContextHandle *handle = raw_handle;
    if (!handle || !key) {
        return qjs_set_error(error_message, "Invalid global property");
    }
    JSValue global = JS_GetGlobalObject(handle->context);
    JSValue value = JS_GetPropertyStr(handle->context, global, key);
    JS_FreeValue(handle->context, global);
    if (JS_IsException(value)) {
        return qjs_set_exception_error(handle->context, error_message, "Global property read failed");
    }
    char *json = qjs_json_stringify(handle->context, value);
    JS_FreeValue(handle->context, value);
    if (!json) {
        return qjs_set_error(error_message, "Global property is not JSON-compatible");
    }
    *result_json = json;
    return 0;
}

int qjs_set_global_json(void *raw_handle, const char *key,
                        const char *value_json, char **error_message) {
    QJSContextHandle *handle = raw_handle;
    if (!handle || !key || !value_json) {
        return qjs_set_error(error_message, "Invalid global property");
    }
    JSValue global = JS_GetGlobalObject(handle->context);
    JSValue value = JS_ParseJSON(handle->context, value_json, strlen(value_json), "<global>");
    if (JS_IsException(value)) {
        JS_FreeValue(handle->context, global);
        return qjs_set_exception_error(handle->context, error_message, "Global property serialization failed");
    }
    int result = JS_SetPropertyStr(handle->context, global, key, value);
    JS_FreeValue(handle->context, global);
    if (result < 0) {
        return qjs_set_exception_error(handle->context, error_message, "Global property write failed");
    }
    return 0;
}

int qjs_register_util(void *raw_handle, void *opaque,
                      QJSLogCallback log_callback,
                      QJSURLRequestCallback url_request_callback) {
    QJSContextHandle *handle = raw_handle;
    if (!handle) {
        return -1;
    }
    handle->opaque = opaque;
    handle->log_callback = log_callback;
    handle->url_request_callback = url_request_callback;
    JSValue util = JS_NewObject(handle->context);
    JSValue log = JS_NewCFunction(handle->context, qjs_log, "log", 2);
    JSValue url_request = JS_NewCFunction(handle->context, qjs_url_request, "urlRequest", 4);
    JS_SetPropertyStr(handle->context, util, "log", log);
    JS_SetPropertyStr(handle->context, util, "urlRequest", url_request);
    JSValue global = JS_GetGlobalObject(handle->context);
    int result = JS_SetPropertyStr(handle->context, global, "util", util);
    JS_FreeValue(handle->context, global);
    return result < 0 ? -1 : 0;
}
