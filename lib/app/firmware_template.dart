const starterFirmware = r'''#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_flash.h"

static void report_status(void) {
    printf("I (0) device: idf=%s,fw=1.0.0\n", esp_get_idf_version());
    printf("I (0) status: ready\n");
    fflush(stdout);
}

static void command_task(void *argument) {
    char line[128];
    while (1) {
        if (fgets(line, sizeof(line), stdin)) {
            line[strcspn(line, "\r\n")] = '\0';
            if (!strcmp(line, "STATUS?")) report_status();
            else if (!strcmp(line, "PING")) puts("I (0) status: PONG");
            else if (!strcmp(line, "HELP")) puts("I (0) status: STATUS? PING HELP");
            else if (line[0]) puts("W (0) command: Unknown command; send HELP");
            fflush(stdout);
        }
        vTaskDelay(pdMS_TO_TICKS(20));
    }
}

void app_main(void) {
    report_status();
    xTaskCreate(command_task, "commands", 4096, NULL, 5, NULL);
    while (1) {
        uint32_t flash_bytes = 0;
        esp_flash_get_size(NULL, &flash_bytes);
        size_t used = heap_caps_get_total_size(MALLOC_CAP_8BIT) - heap_caps_get_free_size(MALLOC_CAP_8BIT);
        printf("I (%lu) telemetry: ram=%.1f,flash=%.1f\n",
               (unsigned long)(xTaskGetTickCount() * portTICK_PERIOD_MS),
               used / 1024.0, flash_bytes / 1024.0);
        fflush(stdout);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
''';
