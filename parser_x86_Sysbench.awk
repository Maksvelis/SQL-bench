#!/usr/bin/awk -f

BEGIN {
    # Параметры таблицы, выравнивание
    num_threads_width = 15
    trans_width = 20
    tps_width = 20
    queries_width = 20
    qps_width = 20
      
    # Вывод столбцов
    printf "%-s%-s%-s%-s%-s\n", "Num threads", "Transactions", "Transactions per sec.", "Queries", "Queries per sec."
}
 
# Извлечение нужных значений из строки статистики
/Number of threads:/ {
    num_threads = $4
}
/transactions:/ {
    num_transactions = $2
    tps = $(NF-2)
    gsub(/[()]/, "", tps) # Удаление скобок вокруг TPS
    printf "%-*s%-*s%-*s", num_threads_width, num_threads, trans_width, num_transactions, tps_width, tps
}
/queries:/ {
    num_queries = $2
    qps = $(NF-2)
    gsub(/[()]/, "", qps) # Удаление скобок вокруг QPS
    printf "%-*s%-*s\n", queries_width, num_queries, qps_width, qps
}
