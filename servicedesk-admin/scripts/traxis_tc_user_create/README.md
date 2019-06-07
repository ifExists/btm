**This is a quick way to create traxis tc users**

* Run the ./massAddLDAPtool.sh
* The tool accepts one parameter 
* Add this argument while running: <tcUserGroups.csv>
* Here is exactly how you use the tool: ./massAddLDAPtool.sh tcUserGroups.csv 
* You'll be prompted to enter your LDAP Password
* You'll be prompted to enter the userID of the tc user that you are adding all of the groups to
* The groups will automatically add to the defined user
* The LDAP Groups will register with service-now the next day
