(local {: autoload} (require "nfnl.module"))
(local core (autoload "nfnl.core"))
(local nvim (autoload "nvim"))

(fn set-mapping [mode from to ...]
  (let [opts (if (= (length [...]) 0) {:noremap true :silent true}
               (. [...] 1))]
    (nvim.set_keymap mode from to opts)))

(local mappings 
  [
   ;; вызов файлового браузера
   ["n" "<F9>" ":<c-u>NvimTreeToggle<CR>"]
   ;; забой убирает подсветку найденных фраз
   ["n" "<BS>" ":nohlsearch<CR>"]
   ;; следующее переназначение позволяет оставаться в визуальном режими при
   ;; интендации выделенного блока с помощью < и >
   ["v" "<" "<gv"]
   ["v" ">" ">gv"]
   ;; навигация между окнами
   ["n" "<C-j>" "<C-w>j"]
   ["n" "<C-h>" "<C-w>h"]
   ["n" "<C-k>" "<C-w>k"]
   ["n" "<C-l>" "<C-w>l"]])

(each [_ mapping (ipairs mappings)]
  (set-mapping (unpack mapping)))

