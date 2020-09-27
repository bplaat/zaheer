#ifndef LIST_H
#define LIST_H

typedef struct List {
    int size;
    int capacity;
    void **items;
} List;

List *list_new(int capacity);

#define list_set(list, position, value) (list->items[position] = value)

#define list_get(list, position) (list->items[position])

void list_add(List *list, void *value);

void list_free(List *list, void (free_function)(void *));

#endif
