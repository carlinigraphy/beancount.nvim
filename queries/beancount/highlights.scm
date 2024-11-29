["balance"
 "open"
 "close"
 "commodity"
 "pad"
 "event"
 "price"
 "note"
 "document"
 "query"
 "custom"
 "pushtag"
 "poptag"
 "pushmeta"
 "popmeta"
 "option"
 "include"
 "plugin"
] @markup.italic

(option
  key: (string) @type
  value: (string) @string)

(account) @type

(date) @variable

(txn) @comment
(txn (flag) @comment.todo)

(payee) @variable @spell
(narration) @bracket @spell

(balance) @markup.strong
(balance amount: _ @markup.italic)
(transaction
  (posting amount: _ @markup.italic))

(currency) @comment

((key_value)
 ":" @bracket)

((key_value
   (key) @_key
   (value) @comment
   (#eq? @_key "memo")))

(tag) @tag
(link) @markup.link

(comment) @comment
