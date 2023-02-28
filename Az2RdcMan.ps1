#Requires -module Az.Compute, Az.Accounts, Az.Storage, Az.Resources, Az.Network

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

    # Overwrite if file already exists. Default is update
    [Parameter(Mandatory = $False)]
    [switch]
    $Overwrite

)


if ((get-azcontext).subscription.id -ne $SubscriptionID)
{  
    If ($NULL -eq (get-azcontext))
    {
      Login-AzAccount -Tenant $TenantID
    } Else {
      $response = Read-Host "Continue as " (get-azcontext).account " Y/N"
      If ($response -ieq "n")
      {
        Login-AzAccount -Tenant $TargetTenant
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