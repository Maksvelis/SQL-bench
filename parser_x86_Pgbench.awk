#!/usr/bin/awk -f
 
BEGIN {
    # Параметры таблицы, выравнивание
    client_width = 10
    thread_width = 12
    tps_width = 20
    trans_width = 20
    latency_width = 20
    init_conn_width = 25
     
    # Вывод столбцов
    printf "%-s%-s%-s%-s%-s%-s\n", "Num Clients", "Num Threads", "TPS", "Num Transactions", "Latency Average", "Initial Connection Time"
}
 
# Извлечение нужных значений из строки запуска pgbench
match($0, /-j\s+([0-9]+)/, arr) {
    num_clients = arr[1]
}
match($0, /-c\s+([0-9]+)/, arr) {
    num_threads = arr[1]
}
 
# Поиск по строкам нужных значений
/number of transactions actually processed:/ {
    num_transactions = $NF
}
/latency average/ {
    latency_average = $(NF-1) " " $NF
}
/initial connection time.*[0-9]+\.[0-9]+/ {
    # Извлечение только числовых значений
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+\.[0-9]+$/) {
            init_conn_time = $i " " $(i+1)
            break
        }
    }
}
/tps/ {
    # Извлечение всех знаков (if present)
    for (i = 1; i <= NF; i++) {
        if ($i == "tps") {
            tps = $(i+2)
            gsub(/[()]/, "", tps) # Удаление TPS знач
            break
        }
    }
     
    # Вывод
    printf "%-*s%-*s%-*s%-*s%-*s%-*s\n", client_width, num_clients, thread_width, num_threads, tps_width, tps, trans_width, num_transactions, latency_width, latency_average, init_conn_width, init_conn_time
}
