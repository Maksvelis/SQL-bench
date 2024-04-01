#!/bin/bash

# Добавляем репо PostgreSQL-14
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
 
# Устанавливаем PostgreSQL-14
apt install postgresql-14 sysbench bc gawk -y

ROOT_PASWD=AscDtr2caER133fvx

# Получаем кол-во потоков
CPU_THREADS=$(lscpu | grep -oP '^CPU\(s\):\s*\K\d+')

MAX_CONNECTIONS=$((CPU_THREADS + (CPU_THREADS * 20 / 100)))

# Изменяем конфигурационный файл PostgreSQL
cd /etc/postgresql/14/main/
sed -i -e "s/^#\?\s*listen_addresses\s*[=]\s*[^\t#]*/listen_addresses = '127.0.0.1'/" postgresql.conf
sed -i -e "/^max_connections/s/[= ][^\t#]*/ = '$MAX_CONNECTIONS'/" postgresql.conf
service postgresql restart
 
# Создаем базу данных "test"
sudo -u postgres createdb test
 
# Создаем пользователя "root" с установленным паролем
sudo -u postgres createuser root
sudo -u postgres psql -d test -c "ALTER USER root WITH PASSWORD '$ROOT_PASWD';"

# Добавляем информацию о подключении к базе данных в файл .pgpass
cat >> /root/.pgpass<<EOF
127.0.0.1:5432:test:root:$ROOT_PASWD
EOF
chmod 0600 /root/.pgpass
chown root:root /root/.pgpass

CORES=$((CPU_THREADS))
 
HOST="127.0.0.1"
TIME="600"
USERPG=root
PORT=5432
PASWD=$ROOT_PASWD
DB=test
FILE2=/root/sysbench_pg.txt

# Создаем базу данных
pgbench --username=root -h "${HOST}" test -i -s 10000
 
THREADS=(1 2 $(echo "scale=0; $CORES * 20 / 100" | bc -l) \
         $(echo "scale=0; $CORES * 40 / 100" | bc -l) \
         $(echo "scale=0; $CORES * 60 / 100" | bc -l) \
         $(echo "scale=0; $CORES * 80 / 100" | bc -l) \
         $(echo "scale=0; $CORES * 99.9 / 100" | bc -l))
 
USERS=()
 
for THREAD in "${THREADS[@]}"
do
  USER=$((THREAD * 2))
  USERS+=($USER)
done
 
FILE=/root/pgbench.txt
 
# Запускаем тесты с одним и двумя потоками
for i in {0..1}
do
  PARAM="-j ${THREADS[$i]} -c ${USERS[$i]}"
 
  echo "pgbench --username=root -h ${HOST} test ${PARAM} -T ${TIME}" >> "${FILE}"
  pgbench --username=root -h "${HOST}" test "${PARAM}" -T "${TIME}" >> "${FILE}"
 
  echo "pgbench --username=root -h ${HOST} test ${PARAM} -S -T ${TIME}" >> "${FILE}"
  pgbench --username=root -h "${HOST}" test "${PARAM}" -S -T "${TIME}" >> "${FILE}"
 
  echo "pgbench --username=root -h ${HOST} test ${PARAM} -N -T ${TIME}" >> "${FILE}"
  pgbench --username=root -h "${HOST}" test "${PARAM}" -N -T "${TIME}" >> "${FILE}"
done
 
# Запускаем тесты с 20%, 40%, 60%, 80%, 99% потоков
for i in {2..6}
do
  PARAM="-j ${THREADS[$i]} -c ${USERS[$i]}"
 
  echo "pgbench --username=root -h ${HOST} test ${PARAM} -T ${TIME}" >> "${FILE}"
  pgbench --username=root -h "${HOST}" test "${PARAM}" -T "${TIME}" >> "${FILE}"
 
  echo "pgbench --username=root -h ${HOST} test ${PARAM} -S -T ${TIME}" >> "${FILE}"
  pgbench --username=root -h "${HOST}" test "${PARAM}" -S -T "${TIME}" >> "${FILE}"
 
  echo "pgbench --username=root -h ${HOST} test ${PARAM} -N -T ${TIME}" >> "${FILE}"
  pgbench --username=root -h "${HOST}" test "${PARAM}" -N -T "${TIME}" >> "${FILE}"
done

 # Запускаем тесты на 1 и 2 потоках
for i in {0..1}
do
    PARAM="${THREADS[$i]}"
    for TEST in 'oltp_read_only.lua' 'oltp_write_only.lua' 'oltp_read_write.lua'
    do
        sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" prepare
        echo "sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM \"/usr/share/sysbench/$TEST\"" >> $FILE2
        sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" run >> $FILE2
        sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" cleanup
    done
done

# Определяем количество потоков для каждого теста в %
for i in {2..6}
do
    PARAM="${THREADS[$i]}"
    for TEST in 'oltp_read_only.lua' 'oltp_write_only.lua' 'oltp_read_write.lua'
    do

        # Запускаем тест
        sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" prepare
echo "sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM \"/usr/share/sysbench/$TEST\"" >> $FILE2
sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" run >> $FILE2
sysbench --db-driver=pgsql --pgsql-host=$HOST --pgsql-port=$PORT --pgsql-user=$USERPG --pgsql-password=$PASWD --pgsql-db=$DB --time=$TIME --threads=$PARAM "/usr/share/sysbench/$TEST" cleanup
    done
done

echo "Test DB done"

exit 0
