#!/bin/bash

#проверяем, что передано правильное количество параметров
if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "ошибка: передано некорректное количество параметров :("
  echo "введите запрос правильно: $0 /путь/к/входной/дир /путь/в/выходной/дир [--max_depth N]"
  exit 1
fi

#сохраняем путь к директориям
INPUT_DIR="$1"
#сохраняем путь к выходной директории
OUTPUT_DIR="$2"
#по умолч max_depth пустая
MAX_DEPTH=""

#проверяем существует ли входная директория
if [ ! -d "$INPUT_DIR" ]; then
  echo "ошибка: входная директория $INPUT_DIR не существует :("
  exit 1
fi

#создаём выходную директорию если её нет
mkdir -p "$OUTPUT_DIR"

#если передан параметр --max_depth, сохраняем его значение
if [[ "$3" == "--max_depth" ]]; then
  MAX_DEPTH="$4"
  #проверяем что max_depth полож число
  if ! [[ "$MAX_DEPTH" =~ ^[0-9]+$ ]]; then
    echo "ошибка: значение max_depth должно быть положительным числом :("
    exit 1
  fi
fi

#функция для копирования файла с уникальным имен
copy_file_flat() {
  local src_file="$1"                   #путь к исходному файлу
  local dest_dir="$2"                    #путь к целевой директории
  local filename="$(basename "$src_file")" #имя файла
  local dest_path="$dest_dir/$filename"  #путь к целевому файлу

  #если файл с таким именем уже существует
  if [ -e "$dest_path" ]; then
    local base="${filename%.*}"          #имя файла без расширения
    local ext="${filename##*.}"           #расширение файла
    [[ "$ext" == "$filename" ]] && ext="" #если расширения нет
    [[ -n "$ext" ]] && ext=".$ext"         #добавляем точку перед расширением
    local i=1
    #пока существует файл с новым именем, увеличиваем номер
    while [ -e "${dest_dir}/${base}${i}${ext}" ]; do
      ((i++))
    done
    dest_path="${dest_dir}/${base}${i}${ext}" #новое уникальное имя
  fi

  cp "$src_file" "$dest_path"             #копируем файл
}

#попытка реализовать функцию для обработки ограничения глубины
process_with_max_depth() {
  local src_dir="$1"                      #путь к текущей папке
  local dst_dir="$2"                      #путь к выходной папке
  local current_depth="$3"                #текущая глубина обхода
  local max_depth="$4"                    #максимальная глубина

  for item in "$src_dir"/*; do             #обходим все элементы в папке
    if [ -f "$item" ]; then
      cp "$item" "$dst_dir/"               #если файл - просто копируем в выходную папку
    elif [ -d "$item" ]; then
      if (( current_depth < max_depth )); then
        #если глубина ещё допустима - продолжаем обход вложенной папки
        local sub_dir_name="$(basename "$item")"
        process_with_max_depth "$item" "$dst_dir/$sub_dir_name" $((current_depth + 1)) "$max_depth"
      else
        #если глубина превышена - переносим всю папку в корень dst_dir
        local base_name="$(basename "$item")"
        local new_path="$dst_dir/$base_name"
        mkdir -p "$new_path"
        cp -r "$item/"* "$new_path/" 2>/dev/null || true
        #после копирования проверяем папку на превышение глубины рекурсивно
        process_with_max_depth "$new_path" "$dst_dir" $((current_depth)) "$max_depth"
        rm -rf "$new_path/$base_name" 2>/dev/null || true
      fi
    fi
  done
}

#main function
if [[ -n "$MAX_DEPTH" ]]; then
  #если указан max_depth - запускаем функцию обработки глубины
  process_with_max_depth "$INPUT_DIR" "$OUTPUT_DIR" 1 "$MAX_DEPTH"
else
  #если нет ограничения по глубине копируем все файлы в плоскую структуру
  find "$INPUT_DIR" -type f | while read -r file; do
    copy_file_flat "$file" "$OUTPUT_DIR"
  done
fi