# Inputs

-f the folder id under which all projects should be linked to the new target billing account

-t the target billing account id

-p for reviewing the planned changes

-a for bulk updating the projects

# Example plan execution

```
bash bulk_change_billing_account.sh -f 123456789012 -t 012ABC-012ABC-012ABC -p
```

# Example apply execution

```
bash bulk_change_billing_account.sh -f 123456789012 -t 012ABC-012ABC-012ABC -a
```