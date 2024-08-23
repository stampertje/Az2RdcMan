#Requires -module Az.Compute, Az.Accounts, Az.Storage, Az.Resources, Az.Network

<#
.SYNOPSIS
This script generates an XML file for the Remote Desktop Manager containing a list of Azure VMs and their private IP 
addresses. Optionally, it can also include a second entry for the public IP address of each VM.

.PARAMETER TenantID
The Azure Active Directory Tenant ID in GUID format.

.PARAMETER SubscriptionID
The GUID of the Azure subscription to use.

.PARAMETER ResourceGroupName
The name of the resource group to process. If not specified, all VMs in the subscription will be processed.

.PARAMETER RdcManfile
The file path to the Remote Desktop Manager connection file to be generated.

.PARAMETER Overwrite
If specified, the script will overwrite an existing connection file. 

.PARAMETER IncludePublicIP
If specified, the script will also include a second entry for the public IP address of each VM.

.EXAMPLE
.\Generate-RdcManAzureVMs.ps1 -TenantID "12345678-1234-5678-abcd-1234567890ab" -SubscriptionID "12345678-1234-5678-abcd-1234567890ab" 
-ResourceGroupName "MyResourceGroup" -RdcManfile "C:\Temp\MyConnections.rdg" -Overwrite -IncludePublicIP

This example generates an XML file for the Remote Desktop Manager containing a list of VMs in the specified resource group, including their 
private and public IP addresses. The connection file is saved to C:\Temp\MyConnections.rdg, overwriting any existing file with the same name.

.NOTES
Author: Nico van Diemen
Date: 09-03-2023
Version: 1.0
#>



[CmdletBinding()]
param (

    # Tenant ID in guid format
    [Parameter(Mandatory = $true)]
    [string]
    $TenantID,

    # subscription guid
    [Parameter(Mandatory=$true)]
    [string]
    $SubscriptionID,

    # If resourcegroup is not specified, all vms in subscription will be processed 
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceGroupName,

    # File path to the Remote Desktop Manager connection file
    [Parameter(Mandatory = $true)]
    [string]
    $RdcManfile,

    # Overwrite if file already exists.
    [Parameter(Mandatory = $False)]
    [switch]
    $Overwrite,

    # Create a second entry for the public IP if the VM has one
    [Parameter(Mandatory =  $false)]
    [switch]
    $IncludePublicIP
)


if ((Test-Path $RdcManfile) -and (-not($Overwrite)))
{
  Write-Warning "The file $RdcManfile exists."
  $confirmation = Read-Host "Do you want to continue? Type 'Yes' to continue."
  if ($confirmation -ne "Yes") {
    Write-Host "Script execution stopped by user" -ForegroundColor Red
    Exit
  }
}


if ((get-azcontext).subscription.id -ne $SubscriptionID)
{  
    If ($NULL -eq (get-azcontext))
    {
      Login-AzAccount -Tenant $TenantID
    } Else {
      $response = Read-Host "Continue as " (get-azcontext).account " Y/N"
      If ($response -ieq "n")
      {
        Login-AzAccount -Tenant $TenantID
      }
    }

  Select-AzSubscription -SubscriptionId $SubscriptionID
}

# If a resource group is specified only process that resource group
If (-not($ResourceGroupName -eq ""))
{
  $VMList = Get-AzVM -ResourceGroupName $ResourceGroupName
} 
Else {
  $VMList = Get-AzVM
}

$VMArray = @()
foreach ($vm in $vmlist)
{
  $vmnicName = $vm.networkprofile.NetworkInterfaces.id.split("/")[$vm.networkprofile.NetworkInterfaces.id.split("/").length-1]
  $interface = Get-AzNetworkInterface -ResourceGroupName $vm.ResourceGroupName -Name $vmnicName
  $PrivateIPAddress = $interface.IpConfigurations.PrivateIpAddress

  #$VMArray += $vm.ResourceGroupName + ";" + $VM.name + ";" + $PrivateIPAddress
  $vmline = @{
    "VMName" = $vm.name
    "VMrg" = $vm.ResourceGroupName
    "VMip" = $PrivateIPAddress
  }

  $VMArray += $vmline
  
  If ($IncludePublicIP)
  {
    If ($null -ne $interface.IpConfigurations.PublicIPAddress)
    {
      $PublicIPName = $interface.IpConfigurations.PublicIPAddress.Id.split("/")[$interface.IpConfigurations.PublicIPAddress.Id.split("/").length-1]
      $PublicIPObject = Get-AzPublicIpAddress -Name $PublicIPName

      $PublicIpAllocationMethod = $PublicIPObject.PublicIpAllocationMethod
      $PublicIPAddress = $PublicIPObject.IpAddress
      
      If ($null -ne $PublicIPObject.DnsSettings.fqdn)
      {
        $publicConnection = $PublicIPObject.DnsSettings.fqdn
        $VMNamePublic = $vm.name + " [Public FQDN]" 
      } else {
        $publicConnection = $PublicIPAddress
        $VMNamePublic = $vm.name + " [Public " + $PublicIpAllocationMethod + "]"
      }

      $vmlinePip += @{
        "VMName" = $VMNamePublic
        "VMrg" = $vm.ResourceGroupName
        "VMip" = $publicConnection
      }

      $VMArray += $vmlinePip
    }
  }
}

$rglist = $VMArray.VMrg | sort-object | get-unique

#region Generate_XML_file
$xml = New-Object System.Xml.XmlDocument

$root = $xml.CreateElement("RDCMan")
$root.SetAttribute("programVersion", "2.92")
$root.SetAttribute("schemaVersion", "3")
$xml.AppendChild($root)

$file = $xml.CreateElement("file")
$root.AppendChild($file)

$credsProfiles = $xml.CreateElement("credentialsProfiles")
$file.AppendChild($credsProfiles)

$props = $xml.CreateElement("properties")
$file.AppendChild($props)

$expanded = $xml.CreateElement("expanded")
$expanded.InnerText = "True"
$props.AppendChild($expanded)

$name = $xml.CreateElement("name")
$name.InnerText = "Azure VMs"
$props.AppendChild($name)
foreach ($rg in $rglist)
{
  # Create group and add VMs
  $group = $xml.CreateElement("group")
  $file.AppendChild($group)

  $props = $xml.CreateElement("properties")
  $group.AppendChild($props)

  $expanded = $xml.CreateElement("expanded")
  $expanded.InnerText = "True"
  $props.AppendChild($expanded)

  $name = $xml.CreateElement("name")
  $name.InnerText = $rg
  $props.AppendChild($name)

  foreach ($vmprops in ($vmarray | Where-object {$_.VMrg -eq $rg}))
  {
    $server = $xml.CreateElement("server")
    $group.AppendChild($server)

    $props = $xml.CreateElement("properties")
    $server.AppendChild($props)

    $displayName = $xml.CreateElement("displayName")
    $displayName.InnerText = $vmprops.VMName
    $props.AppendChild($displayName)

    $name = $xml.CreateElement("name")
    $name.InnerText = $vmprops.VMip
    $props.AppendChild($name)
  }
}

$root.AppendChild($xml.CreateElement("connected"))
$root.AppendChild($xml.CreateElement("favorites"))
$root.AppendChild($xml.CreateElement("recentlyUsed"))


$xml.Save($RdcManfile)


#endregion Generate_XML_file