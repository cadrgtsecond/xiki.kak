#include <regex.h>

regex_t *init_regex_t();
void cleanup_regex_t(regex_t *reg);
size_t regex_nsub(regex_t *reg);
