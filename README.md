# azure-create-users
Creating IAAS users in bulks
###############################################################################################################################################################################################

This script is for bulk user accounts creations and pass/key resets for Azure VMs.
It  will ask you to input a server list and a file holding the usernames, passwords and public keys you want to setup
Mind the syntax of both files and the PUB key format!!! Pub Key needs to be on one line.
You will also get to choose the subscription you want to run the script against. It will not run on all subscriptions by itself, but it will go through all resource groups in a subscription.
It will then go through your list and create/reset the credentials of the users you've given it using the VMAccessForLinux or VMAccessAgent
On a Windows machine it creates local admin users with Password Never Expires option and the user/pass combination
On a Linux machine it creates users with sudo capabilities. It sets user, pass and key combination (both)
#
To use the script, prepare first the server list file and the CSV with the credentials following the example and just run. 
#
# version 0.1
# Ivaylo Tsokov
#
##################################################################################################################################################################################################
