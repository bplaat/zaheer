#include "list.h"
#include <stdlib.h>

List *list_new(int capacity) {
    List *list = malloc(sizeof(List));
    list->size = 0;
    list->capacity = capacity;
    list->items = malloc(sizeof(void *) * capacity);
    return list;
}

void list_add(List *list, void *value) {
    if (list->size == list->capacity) {
        list->capacity *= 2;
        list->items = realloc(list->items, sizeof(void *) * list->capacity);
    }

    list->items[list->size++] = value;
}

void list_free(List *list, void (free_function)(void *)) {
    for (int i = 0; i < list->size; i++) {
        free_function(list->items[i]);
    }

    free(list->items);
    free(list);
}
