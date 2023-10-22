(local {: autoload} (require "nfnl.module"))
(local core (autoload "nfnl.core"))
(local nvim (autoload "nvim"))

(fn file-exists? [filename]
  "Проверяет, существует ли файл."
  (let [file (io.open filename)
        exists (~= file nil)]
    (when exists
      (io.close file))
    exists))

(let [
      options [;; размер табуляции - 4 пробела
               [:tabstop 4]
               ;; заменять табуляции пробелами для всех файлов, кроме Makefile
               [:expandtab true]
               ;; количество пробелов для автовыравнивания кода
               [:shiftwidth 4]
               ;; показывать относительные номера строк
               [:relativenumber true]
               ;; показывать номер текущей строки
               [:number true]
               ;; показывать колонку с метками (иначе она будет показываться только когда
                                                     ;; есть метки, например, предупреждения или ошибки)
               [:signcolumn "yes"]
               ;; вертикальный сплит открывает окно справа
               [:splitright true]
               ;; горизонтальный split открывает окно снизу
               [:splitbelow true]
               [:ignorecase true]
               [:smartcase true]]]
  (each [_ option (ipairs options)]
    (let [name (. option 1)
          value (. option 2)]
      (core.assoc nvim.o name value))))
