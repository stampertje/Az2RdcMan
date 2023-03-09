# Generate-RdcManAzureVMs.ps1

This script generates an XML file for the Remote Desktop Manager containing a list of Azure VMs and their private IP addresses. Optionally, it can also include a second entry for the public IP address of each VM.

Get the Sysinternals Remote Desktop Connection Manager here:
- http://live.sysinternals.com/RDCMan.exe
- https://learn.microsoft.com/en-us/sysinternals/downloads/rdcman

## Required modules

- Az.Compute
- Az.Accounts
- Az.Storage
- Az.Resources
- Az.Network

## Parameters

|Parameter|Mandatory|Description|
|-----|-----|----|
|TenantID|Yes|The Azure Active Directory Tenant ID in GUID format|
|SubscriptionID|Yes|The GUID of the Azure subscription to use
|ResourceGroupName|No|The name of the resource group to process. If not specified, all VMs in the subscription will be processed.
|RdcManfile|Yes|The file path to the Remote Desktop Manager connection file to be generated
|Overwrite|No|If specified, the script will overwrite an existing connection file.
|IncludePublicIP|No|If specified, the script will also include a second entry for the public IP address of each VM.

## Examples

```
.\Generate-RdcManAzureVMs.ps1 -TenantID "12345678-1234-5678-abcd-1234567890ab" -SubscriptionID "12345678-1234-5678-abcd-1234567890ab" -ResourceGroupName "MyResourceGroup" -RdcManfile "C:\Temp\MyConnections.rdg" -Overwrite -IncludePublicIP
```

This example generates an XML file for the Remote Desktop Manager containing a list of VMs in the specified resource group, including their private and public IP addresses. The connection file is saved to C:\Temp\MyConnections.rdg, overwriting any existing file with the same name.

## Notes

- Author: Nico van Diemen
- Date: 09-03-2023
- Version: 1.0
