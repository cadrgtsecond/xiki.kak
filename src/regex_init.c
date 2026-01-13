#include <stdlib.h>
#include <regex.h>

regex_t *init_regex_t() {
    return malloc(sizeof(regex_t));
}
void cleanup_regex_t(regex_t *reg) {
    free(reg);
}
size_t regex_nsub(regex_t *reg) {
    return reg->re_nsub;
}
