#ifndef MOCKINGSTAR_QJS_BRIDGE_H
#define MOCKINGSTAR_QJS_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*QJSLogCallback)(void *opaque, const char *message, const char *severity);
typedef int (*QJSURLRequestCallback)(void *opaque,
                                     const char *url,
                                     const char *headers,
                                     const char *method,
                                     const char *body,
                                     char **body_json,
                                     char **headers_json,
                                     char **error_message);

void *qjs_context_new(size_t memory_limit, size_t stack_limit, unsigned int timeout_ms);
void qjs_context_free(void *handle);
void qjs_context_reset(void *handle);

int qjs_evaluate(void *handle, const char *source, const char *filename, char **error_message);
int qjs_call_json(void *handle,
                  const char *function_name,
                  const char *arguments_json,
                  char **result_json,
                  char **error_message);
int qjs_call_async_json(void *handle,
                        const char *function_name,
                        const char *arguments_json,
                        unsigned int timeout_ms,
                        unsigned int max_jobs,
                        char **result_json,
                        char **error_message);
int qjs_get_global_json(void *handle,
                        const char *key,
                        char **result_json,
                        char **error_message);
int qjs_set_global_json(void *handle,
                        const char *key,
                        const char *value_json,
                        char **error_message);

int qjs_register_util(void *handle,
                      void *opaque,
                      QJSLogCallback log_callback,
                      QJSURLRequestCallback url_request_callback);

char *qjs_copy_string(const char *value);
void qjs_free_string(char *value);
void *qjs_get_user_opaque(void *handle);
void qjs_set_user_opaque(void *handle, void *opaque);

#ifdef __cplusplus
}
#endif

#endif
