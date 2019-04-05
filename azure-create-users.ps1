###############################################################################################################################################################################################
#
# This script is for bulk user accounts creations and pass/key resets for Azure VMs.
# 
# It  will ask you to input a server list and a file holding the usernames, passwords and public keys you want to setup
# Mind the syntax of both files and the PUB key format!!! Pub Key needs to be on one line.
# You will also get to choose the subscription you want to run the script against. It will not run on all subscriptions by itself, but it will go through all resource groups in a subscription.
# It will then go through your list and create/reset the credentials of the users you've given it using the VMAccessForLinux or VMAccessAgent
# On a Windows machine it creates local admin users with Password Never Expires option and the user/pass combination
# On a Linux machine it creates users with sudo capabilities. It sets user, pass and key combination (both)
#
# To use the script, prepare first the server list file and the CSV with the credentials following the example and just run. 
#
# version 0.1
# ivaylo.tsokov@dxc.com
#
##################################################################################################################################################################################################

function Check-Modules {
###########################################
# Check if required modules are installed #
###########################################

Echo "#---------------------------------------------------------------------------------#" | timestamp
$Modules = @("AzureRm")
foreach($Module in $Modules)
{
    if (Get-Module -ListAvailable -Name $Module) 
    {
        Write-Host "$Module Module exists"
    } 
    else 
    {
        Install-Module -Name $Module -Force -AllowClobber
        Import-Module -Name $Module -Force
    } 
} 
}

Function Select-AzureSubscription{
Echo "#---------------------------------------------------------------------------------# `n" |  timestamp
# Login to Azure Account
try
{
   $login = Login-AzureRmAccount -ErrorAction Stop

}
catch
{

    Write-Error "User Cancelled The Authentication" -ErrorAction Stop
}

try
{
    $subscriptionList = Get-AzureRmSubscription -WarningAction silentlyContinue
    $select = $subscriptionList | Select SubscriptionId, Name, State, TenantId | Out-GridView -OutputMode Single -Title "Please select a subscription"
    $selectedSubscriptionID = $select.SubscriptionId
    Write-Host "You have selected the subscription: $selectedSubscriptionID.`n" -ForegroundColor green
}
catch
{
    Write-Host "User Cancelled The Selection" -ForegroundColor Yellow

}
 
 if($selectedSubscriptionID -eq $null)
 {
    Write-Host "User Cancelled The Selection" -ForegroundColor Yellow

 }
 else
 {
    # Setting the selected subscription
    $subscription = Select-AzureRmSubscription -SubscriptionId $selectedSubscriptionID
    $sub = ($subscription.Subscription).Name
    Write-host "$sub has been chosen successfully."
 }



}

function Find-File {
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    Multiselect = $false # Multiple files can be chosen
	Filter = 'Textfiles (*.txt, *.csv)|*.txt;*.csv' # Specified file types
}
 
[void]$FileBrowser.ShowDialog()

$file = $FileBrowser.FileName;

If($FileBrowser.FileNames -like "*\*") {

	# Do something 
	return $FileBrowser.FileName
}

else {
    Write-Host "Cancelled by user"
}

}

function Create-AzureLinuxAccounts ([string]$VMName,[String]$resourceGroup,[String]$username,[String]$password,[String]$pubKey,[string]$location){

$PublicConf = '{}'
$PrivateConfig = '{"username":"' + $username + '", "password": "' + $password + '", "ssh_key":"' + $pubKey + '"}'
$ExtensionType = 'VMAccessForLinux'
$ExtensionName = 'enablevmaccess'
$Publisher = 'Microsoft.OSTCExtensions'
$Version = '1.4'
# Begin execution
Set-AzureRmVMExtension -ExtensionName $ExtensionName -ExtensionType $ExtensionType -Publisher $Publisher -ResourceGroupName $resourceGroup -VMName $VMName -TypeHandlerVersion $Version -ProtectedSettingString $PrivateConfig -SettingString $PublicConf -Location $location
}

function Create-AzureWindowsAccounts ([string]$VMName,[String]$resourceGroup,[String]$username,[String]$password,[string]$location){

$ExtensionName = 'enablevmaccess'
$secPassword = $password | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$secPassword)
# Begin execution

Set-AzureRmVMAccessExtension -ResourceGroupName $resourceGroup -VMName $VMName -Name $ExtensionName -Location $location -TypeHandlerVersion "2.0" -Credential $credential 
}

filter timestamp {"$(Get-Date -Format G): $_"}

###################
# Check PSVersion #
###################

$Link = "https://www.microsoft.com/en-us/download/details.aspx?id=50395"
$ps = $psversiontable.PSVersion
$Major = $ps.Major
$Minor = $ps.Minor
$version = "$Major"+'.'+"$Minor"
Echo "#---------------------------------------------------------------------------------#" |  timestamp

if($version -lt 5)
{
    Write-host "`nCurrent Powershell Version: $version. Upgrade Powershell version to 5.0 or above to continue the script execution." -ForegroundColor Yellow 
    Write-host "`nLink: $Link`n" -ForegroundColor DarkCyan 
    Write-Error " Script execution stopped " -ErrorAction Stop 
}
else
{
    write-output "`nPowershell Version: $version`nContinuing with the script execution..." |  timestamp
}


Check-Modules
Write-Output "#---------------------------------------------------------------------------------#" |  timestamp
Write-host "Select the Azure Subscription to run the script against." -ForegroundColor Yellow 
Select-AzureSubscription
Write-Output "#---------------------------------------------------------------------------------#" |  timestamp
Write-host "Select the server list file. Each server needs to be a new line in a txt file." -ForegroundColor Yellow 
$serverList=$null
$serverList=get-content (Find-File) 

if ($serverList -eq $null) {Write-Error "Server List is empty" -ErrorAction Stop  }

Write-Output "The script will be executed against server(s) `n$serverlist"  | timestamp

Write-host "Select the credentials csv file. Syntax needs to be Username,Password,PublicKey. See example." -ForegroundColor Yellow 
$userPassKey=$null
$userPassKey=Import-Csv (Find-File) 
if ($userPassKey -eq $null) {Write-Error "User List is empty" -ErrorAction Stop  }

Write-Output "The script will be executed against user(s) `n$userPassKey"  | timestamp

$VMs=get-azurermvm

foreach ($server in $serverList){

    foreach ($VM in $VMs){

    if ($server -eq $VM.Name)
    {
        write-Output "Server $($VM.Name) Found in Resource Group $($VM.ResourceGroupName)" | timestamp
        foreach ($user in $userPassKey) {
        write-Output "Attempting to create $($user.username) on $($VM.Name)" | timestamp
        if ($VM.StorageProfile.OsDisk.OsType -eq "Windows") {Create-AzureWindowsAccounts -VMName $VM.Name -resourceGroup $VM.ResourceGroupName -username $user.username -password $user.password -location $VM.Location}
        elseif ($VM.StorageProfile.OsDisk.OsType -eq "Linux") {Create-AzureLinuxAccounts -VMName $VM.Name -resourceGroup $VM.ResourceGroupName -username $user.username -password $user.password -pubKey $user.PublicKey -location $VM.Location}
        else {write-Output "Server $($VM.Name) Found in Resource Group $($VM.ResourceGroupName) has an OS that is not supported by this script" | timestamp}

        }
        Write-Output "#---------------------------------------------------------------------------------#" |  timestamp

    }


    }


}
