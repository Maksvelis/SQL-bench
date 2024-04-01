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
/Время выполнения/ {
    printf "%-35s %20s\n", "Время выполнения", $(NF-1) " сек"
}
/Number of clients running queries:/ {
    printf "%-35s %20s\n", "Number of clients", $NF
}
/Average number of queries per client/ {
    printf "%-35s %20s\n", "Average number of queries per client", $NF
}
