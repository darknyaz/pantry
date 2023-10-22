(each [_ mod (ipairs ["keymaps" "settings"])]
  (require (.. "config." mod)))
