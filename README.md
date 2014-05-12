bankparse
=========

Parsing emails from Czech banks.

This is the original code that was once used in the Futu project to parse emails from Czech banks into JSON.

Licensed under MIT.

I don't plan to maintain it. Use it for inspiration/fun/profit.

The meat is located in the lib/Futu/Format/ files.

It works like this:

   * bank is determined from email by sender
   * email format is determined (every bank has different formats) by content of email
   * email format (fancy regular expression) is applied to the normalized text of email
