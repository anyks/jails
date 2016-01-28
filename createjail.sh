#!/bin/sh

# Адрес текущего каталога
root=$(cd "$(dirname "$0")" && pwd)

# Последняя цифра
lastnum=0

# Функция извлечения последней цифры ip адреса
numberIP(){
	lastnum=`expr "$1" : '[0-9]\{1,3\}[\.][0-9]\{1,3\}[\.][0-9]\{1,3\}[\.]\([0-9]\{1,3\}\)'`
}

# Функция извлечения данных из конфига
readConf(){
	# Конфигурационный файл
	config="${root}/settings/config.conf"
	# Проверяем на существование файла
	if [ -f ${config} ]; then
			# Подгружаем данные из конфига
			for param in $1
			do
					# Извлекаем данные из конфиг файла
					new_param=`awk -F"[,:]" '{for(i=1;i<=NF;i++){if($i~/'${param}'\042/){print $(i+1)}}}' "${config}"`
					new_param=`echo ${new_param} | tr -d \"`
					# Создаем переменную нужного нам вида
					eval ${param}=${new_param}
			done
	fi
}

# Считываем конфиг
readConf "host eif ip jails"

# Если название хоста введено
if [ -n "$1" ]; then
	# Запоминаем название хоста
	host=$1
fi

# Если название сетевого интефрейса введено
if [ -n "$2" ]; then
	# Запоминаем название сетевого интефрейса
	eif=$2
fi

# Если ip адрес сервера введен
if [ -n "$4" ]; then
	# Запоминаем ip адрес сервера
	ip=$4
fi

# Если адрес каталога для хранения контейнеров введен
if [ -n "$5" ]; then
	# Запоминаем адрес каталога для хранения контейнеров
	jails=$5
fi

# Выводим сообщение в консоль
echo "Введите название контейнера, в нижнем регистре"

# Считываем название контейнера
read jailname

# Если пользователь не ввел название контейнера
if [ -z "$jailname" ]; then
	# Выводим сообщение в консоль
	echo "Название контейнера не введено!"
else
	# Выводим сообщение в консоль
	echo "Уже существующие контейнеры"
	
	# Выводим список созданных контейнеров
	jls
	
	# Выводим сообщение в консоль
	echo "Введите ip адрес (например 192.168.0.1)"
	
	# Считываем ip адрес
	read jailip
	
	# Если пользователь не ввел номер ip адреса
	if [ -z "$jailip" ] || [ -z $(echo $jailip | awk -F "." '{if ( NF != 4 ) print ""; else if ( $1 > 0 && $1 < 255 && $2 >=0 && $2 < 255 && $3 >=0 && $3 < 255 && $4 > 0 && $4 < 255 ) print "1"; else print ""}') ]; then
		# Выводим сообщение в консоль
		echo "IP адрес введен не верно"
	else
		# Извлекаем последние цифры ip адреса
		numberIP $jailip
		
		# Уменьшаем значение ip адреса
		tmpnumberalias=$((lastnum-=1))
		
		# Выводим сообщение в консоль
		echo "Введите номер алиаса сетевого интерфейса (ifconfig_${eif}_alias[X])"
		echo "Можно ничего не вводить, тогда будет установлен алис: ifconfig_${eif}_alias${tmpnumberalias}"
		
		# Проверяем ввод алиаса сетевого интерфейса
		read numberalias
		
		# Если пользователь не номер алиаса
		if [ -z "$numberalias" ]; then
			# Запоминаем номер алиаса ip адрес
			numberalias=${tmpnumberalias}
		fi
		
		# Выводим результат в консоль
		echo "Будет использоваться алиас ifconfig_${eif}_alias${numberalias}"
		
		# Устанавливаем значение по умолчанию (что первоначальную установку контейнеров проводить не надо)
		numberjail="NO"
		
		# Выводим сообщение в консоль
		echo "Нужно ли произвести первоначальную инициализацию контейнеров? YES|NO [Default NO]"
		
		# Считываем нужно ли произвести первоначальную инициализацию контейнеров
		read numberjail
		
		# Функция создания алиаса
		createAlias(){
			# Добавляем alias сетевой карты
			printf "\n# Alias Jail ${jailname}\nifconfig_${eif}_alias$1=\"inet ${jailip} netmask $2\"\n" >> /etc/rc.conf
			# Прописываем конфигурационные данные контейнера
			printf "${jailname} {\n\thost.hostname = \"${jailname}.${host}\";\n\tip4.addr = \"${eif}|${jailip} netmask $2\";\n}\n\n" >> /etc/jail.conf
		}

		# Считываем первый ли этот контейнер
		if [ "$numberjail" = "YES" ]; then
			# Копируем базовый конфиг
			cp ${root}/"configs"/jail.conf /etc/jail.conf
			# Прописываем сетевой интерфейс
			printf "interface = \"${eif}\";\t\t\t\t\t\t# Сетевой интерфейс клетки\n" >> /etc/jail.conf
			# Прописываем параметры монтирования procfs
			printf "mount += \"procfs ${jails}/\${name}/proc procfs rw 0 0\";\t# Монтируем procfs в клетке\n" >> /etc/jail.conf
			# Прописываем адрес каталога контейнеров
			printf "path = \"${jails}/\${name}\";\t\t\t\t# Рутовая директория jail\n\n" >> /etc/jail.conf
			# Активируем контейнер
			printf "\n# Jails\njail_enable=\"YES\"\n" >> /etc/rc.conf
			# Записываем выбранный алиас
			createAlias "0" "255.255.0.0"
		else
			# Записываем выбранный алиас
			createAlias ${numberalias} "255.255.255.255"
		fi
		
		# Создаем файл fstab
		printf "/usr/ports\t${jails}/${jailname}/usr/ports\tnullfs\trw\t0\t0" >> /etc/fstab"."${jailname}
		
		# Создаем каталог контейнера
		mkdir -p ${jails}/${jailname}
		
		# Переходим в каталог с исходниками
		cd /usr/src
		
		# Копируем данные мира в контейнер
		make installworld DESTDIR=${jails}/${jailname}
		make distribution DESTDIR=${jails}/${jailname}
		
		# Переходим обратно в наш каталог
		cd ${root}
		
		# Удаляем ненужные конфиги в контейнере
		rm ${jails}/${jailname}/etc/csh.cshrc
		rm ${jails}/${jailname}/etc/profile
		rm ${jails}/${jailname}/etc/resolv.conf
		
		# Копируем базовые конфиги в контейнер
		cp -v ${root}/"configs"/rc.conf ${jails}/${jailname}/etc/rc.conf
		cp -v ${root}/"configs"/csh.cshrc ${jails}/${jailname}/etc/csh.cshrc
		cp -v ${root}/"configs"/profile ${jails}/${jailname}/etc/profile
		cp -v ${root}/"configs"/make.conf ${jails}/${jailname}/etc/make.conf
		cp -v ${root}/"configs"/resolv.conf ${jails}/${jailname}/etc/resolv.conf
		cp -v ${root}/"configs"/login.conf ${jails}/${jailname}/etc/login.conf
		
		# Прописываем host сервера в контейнере
		printf "${ip}\t${host}\tproxy\n${jailip}\t${jailname}.${host}\t${jailname}\n" >> ${jails}/${jailname}/etc/hosts
		
		# Прописываем host сервера на основной машине
		printf "${jailip}\t${jailname}.${host}\n" >> /etc/hosts
		
		# Создаем каталог etc
		mkdir -p ${jails}/${jailname}/usr/local/etc
		
		# Копируем файл временной зоны
		cp /usr/share/zoneinfo/Europe/Moscow ${jails}/${jailname}/etc/localtime
		
		# Создаем каталог для портов
		mkdir ${jails}/${jailname}/usr/ports

		# Пересобираем кэш пользователя
		cap_mkdb -f ${jails}/${jailname}/etc/termcap ${jails}/${jailname}/etc/login.conf
		
		printf "\n*******************************************\n \
		\nСоздание контейнера ${jailname} закончено!\n \
		\nДля запуска контейнера набери\n \
		\n# service jail start ${jailname}\n \
		\nПросмотреть запущенные контейнеры\n \
		\n# jls\n \
		\nВход в контейнер\n \
		\njexec ${jailname} tcsh\n \
		\nДля перевода на русский язык нужно прописать следующие строки\n \
		\n# pw usermod -n root -L russian\n \
		\n*******************************************\n\n"
	fi
fi
