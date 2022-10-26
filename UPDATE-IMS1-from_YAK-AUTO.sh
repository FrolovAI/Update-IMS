#!/bin/bash

##    Обновление ИМС-1 с сервера YAK на рабочих машинах сотрудников.
##    Для обновления поместить скрипт в папку с обновляемым ИМСом и запустить его выполнение.
##
##################################################### ПОДГОТОВКА ##############################################################
# Проверка прав пользователя
  sudo -v &>/dev/null
  if [ $? != 0 ]
   then echo "---------------------------------------------------------------------------"
        echo "Ваш пользователь '"$USER"' не может выполнить обновление ИМС.";
        echo "Выполните обновление от имени пользователя с правами администратора (user)!"
        echo "---------------------------------------------------------------------------"
        sleep 5 ; exit 1
  fi
# Проверка наличия структуры ИМС
  if ! [ -d ./bin -a -d ./bm -a -d ./conf -a -d ./rlibs -a -d ./sdk ]
   then echo "В каталоге не найдена структура ИМС" ;
     while true; do
       read -p "Всё равно обновить ИМС в этом каталоге?      Yes/No      " yn
       case $yn in
           [Yy]* ) break;;
           [Nn]* ) echo "Завершение..."; sleep 1; exit 1;;
               * ) echo "       Введите Yes или No";;
       esac
     done
  fi
# Проверка наличия / установка lftp
  which lftp &>/dev/null
  if [ $? -ne 0 ]
   then echo "Подготовка..." ;
        sudo apt-get -y install lftp &>/dev/null
  fi
# Проверка доступности YAK
  ping -c1 100.100.105.110 &>/dev/null
  if [ $? -ne 0 ]
   then echo "Сервер YAK недоступен"
   exit 1
  fi
# Определение версии ОС Астра, пути к ИМСам на YAKe
  vers_OS=`lsb_release -r | cut -f2`
  ims_path=/eims_versions/astra-$vers_OS
##################################################### ФУНКЦИИ #################################################################
# Функция - выбор ИМС из списка вручную
  vibor-ims () {
               echo "Выберите ИМС для обновления:"
               PS3="Введите порядковый номер обновляемого ИМС: "
               select ims_name in `lftp -e "cls -1B $ims_path/$1 | tr -d "/" && exit" 100.100.105.110`
                    do 
                      if [ -z "$ims_name" ]
                       then vibor-ims $1
                      fi
                    echo "Выбран:  "$ims_name
                    t_ver $1
                    break
               done
               }
# Функция - поиск крайней версии
  n_ver () {
           new_vers=`lftp -e "cls --sort=date $ims_path$dob_ims/$ims_name | head -1 && exit" 100.100.105.110 2>/dev/null`
           }
# Функция - если в  каталоге пусто
  t_ver () {
    test_vers=`lftp -e "cls -1B --sort=date $ims_path$dob_ims/$ims_name | head -1 && exit" 100.100.105.110 2>/dev/null`
   if [ -z "$test_vers" ]
    then echo "Нет доступных версий для обновления"
         echo "Выберите дальнейшее действие:"
         echo "1 - Выбрать другую версию ИМС"
         echo "2 - Выход без обновления"
         while true; do
               read -p "Введите  1  или  2     " vbr
               case $vbr in
                [1] ) vibor-ims $1 ;  break;;
                [2] ) echo "Завершение..."; sleep 1; exit 0;;
                * ) echo "Введите  1  или  2";;
               esac
         done
   fi
           }
##################################################### ОПРЕДЕЛЕНИЕ ИМС #########################################################
# Определение версии установленного ИМС
  ustan_IMS=`head -n 5 whatisit.txt 2>/dev/null | tail -n 1 | cut -c 19-`
  ims_name=eims-$ustan_IMS
# Поправки на несоответствие наименований версий ИМС записям в файлах whatisit.txt
      # 0.0.7 (Astra-1.5,-1.6)
         if [ "$ustan_IMS" = "0.0.7" ]
          then  ims_name=eims-master
         fi
      # master-nh (Astra-1.5)
         if [ "$ustan_IMS" = "0.0.7_nh" ]
          then ims_name=eims-master-nh
         fi
      # 1.34.0-ota (Astra-1.6)
         if [ "$ustan_IMS" = "1.34.0" ]
          then echo "Уточните версию:"
               vibor-ims eims-1.34.0*
               t_ver eims-1.34.0*
         fi
      # trunk (Astra-1.5)
         if [ "$ustan_IMS" = "0.0.0" ]
          then ims_name=eims-trunk
         fi
  # Поправки #
  # Поправки #
  # Поправки #
# Окончание поправок, определено имя установленного ИМС
#
# Если имя установленного ИМС не определено - выбор вручную
  if [ -z "$ustan_IMS" ]
   then
        vibor-ims eims*
        t_ver eims*
  fi
# Поиск крайней (по дате создания) сборки ИМС
  n_ver
# Для определенной версии ИМС нет актуальной сборки (несоответствующая запись в whatisit.txt) - выбор вручную
  if [ -z "$new_vers" ]
   then
       vibor-ims eims*
       t_ver eims* ; n_ver
  fi
# Если в каталоге пусто
  t_ver eims*
# Уточнение, если в каталоге не архивы сборок, а каталог(и)
  if [[ $test_vers != *.tar.gz ]]
   then echo "Уточните версию:"
       dob_ims=/$ims_name
       vibor-ims $dob_ims
       t_ver $dob_ims ;  n_ver
  fi
##################################################### ОБНОВЛЕНИЕ ИМС ##########################################################
# Определение владельца папки с ИМСом, установка прав, пользователя для обновления
  vl_ims=`stat -c %U $PWD`
  gr_ims=`stat -c %G $PWD`
  sudo chmod -R 777 $PWD
  sudo chown -R $USER $PWD
# Скачивание версии ИМС во временную папку
  show_ims=`echo $ims_name | cut -c 6-`
  echo "Скачивается версия ИМС $show_ims:"
  echo `lftp -e "cls -B --sort=date $ims_path$dob_ims/$ims_name | head -1 && exit" 100.100.105.110`
  mkdir -p temp_ims
  lftp -e "get $new_vers -o ./temp_ims/eims.tar.gz && exit" 100.100.105.110 &>/dev/null
# Установка новых файлов из архива
  echo "Обновление ИМС $show_ims..."
  tar xfz ./temp_ims/eims.tar.gz --strip=2
##################################################### ЗАВЕРШЕНИЕ ##############################################################
# Удаление временной папки
  rm -r ./temp_ims
# Восстановление владельца папки с ИМСом,если владелец был не root
# Если владелец был root - смена на текущего пользователя и если обновление под root-ом - смена на $SUDO_USER
  sudo chmod -R 777 $PWD
  if [ $vl_ims != root ]
   then sudo chown -R $vl_ims: $PWD
  elif [ $USER != root ]
        then sudo chown -R $USER: $PWD
        else sudo chown -R $SUDO_USER: $PWD
  fi
# Ярлыки запуска
  ./conf/scriptwriters/___Creator_runer_eims.sh -sd &>/dev/null
  echo "----------Завершено----------"
  sleep 1
  exit 0

