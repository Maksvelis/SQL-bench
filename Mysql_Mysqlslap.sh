#!/bin/bash

# Устанавливаем пароль для пользователя "admin" MySQL
MYSQL_PASWD="skgvms244lfFSgffdss"

# Устанавливаем MySQL-сервер 8.0 и Sysbench
apt install mysql-server-8.0 sysbench bc -y

# Получаем кол-во потоков
THREADS=$(lscpu | grep -oP "^CPU\(s\):\s*\K\d+")
MAX_CONNECTIONS=$((THREADS + (THREADS * 20 / 100)))

# Изменяем конфигурационный файл MySQL
cd /etc/mysql/mysql.conf.d/
sed -i -e "/^bind-address/s/[= ][^\t#]*/ = '127.0.0.1'/" mysqld.cnf
sed -i -e "/^mysqlx-bind-address/s/[= ][^\t#]*/ = '127.0.0.1'/" mysqld.cnf
sed -i -e "/^max_connections/s/[= ][^\t#]*/ = '$MAX_CONNECTIONS'/" mysqld.cnf
service mysql restart

# Создаем базу данных "test" и пользователя "admin" с установленным паролем
echo "CREATE DATABASE test;" | mysql
echo "USE test;" | mysql
echo "CREATE USER 'admin'@'localhost' IDENTIFIED BY '$MYSQL_PASWD';" | mysql
echo "GRANT ALL ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;" | mysql

FILE=/root/sysbench_mysql.txt
FILE2=/root/mysqlslap.txt

# Задаем параметры подключения к БД и время тестирования
USER=admin
HOST=127.0.0.1
PORT=3306
PASWD=$MYSQL_PASWD
DB=test
TIME=600

THREADS=(1 2 $(echo "scale=0; $THREADS * 20 / 100" | bc -l) \
         $(echo "scale=0; $THREADS * 40 / 100" | bc -l) \
         $(echo "scale=0; $THREADS * 60 / 100" | bc -l) \
         $(echo "scale=0; $THREADS * 80 / 100" | bc -l) \
         $(echo "scale=0; $THREADS * 99.9 / 100" | bc -l))

# Запускаем тесты на 1 и 2 потоках
for i in {0..1}
do
    PARAM="${THREADS[$i]}"
    for TEST in 'oltp_read_only.lua' 'oltp_write_only.lua' 'oltp_read_write.lua'
    do
        sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" prepare
        echo "sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM \"/usr/share/sysbench/$TEST\"" >> $FILE
        sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" run >> $FILE
        sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" cleanup
    done
done

# Запускаем тесты на % от потоков
for i in {2..6}
do
    PARAM="${THREADS[$i]}"
    for TEST in 'oltp_read_only.lua' 'oltp_write_only.lua' 'oltp_read_write.lua'
    do

        # Запускаем тест
        sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" prepare
        echo "sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM \"/usr/share/sysbench/$TEST\"" >> $FILE
        sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" run >> $FILE
        sysbench --db-driver=mysql --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER --mysql-password=$PASWD --mysql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" cleanup
    done
done

# Запускаем тесты с одним и двумя потоками
for i in {0..1}
do
  PARAM="${THREADS[$i]}"
 
  echo "/usr/bin/time -f "Время выполнения %e сек" "${FILE2}" -a -o mysqlslap --auto-generate-sql --concurrency=${PARAM} --iterations=1 --number-of-queries=100000" >> "${FILE2}"
  /usr/bin/time -f "Время выполнения %e сек" -a -o "${FILE2}" mysqlslap --auto-generate-sql --concurrency="${PARAM}" --iterations=1 --number-of-queries=100000 >> "${FILE2}"
done
 
# Запускаем тесты с 20%, 40%, 60%, 80%, 99% потоков
for i in {2..6}
do
  PARAM="${THREADS[$i]}"
 
 echo "/usr/bin/time -f "Время выполнения %e сек" "${FILE2}"-a -o  mysqlslap --auto-generate-sql --concurrency=${PARAM} --iterations=1 --number-of-queries=100000" >> "${FILE2}"
  /usr/bin/time -f "Время выполнения %e сек" -a -o "${FILE2}" mysqlslap --auto-generate-sql --concurrency="${PARAM}" --iterations=1 --number-of-queries=100000 >> "${FILE2}"
done
 
echo "Test DB done"

exit 0
