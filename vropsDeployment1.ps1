param(
	[Parameter(Mandatory=$true)] [String]$configFile,
	[switch]$deployESXi,
	[switch]$deployVCSA,
	[switch]$configureVCSA,
	[switch]$configureHosts,
	[switch]$configureVDSwitch,
	[switch]$configureVSAN,
	[switch]$deployNSXManager,
	[switch]$configureNSX,
	[switch]$deployvRAAppliance
)
# William Lam
# Edited by Simon Eady to support vDS
# Edited by Frode Garnes for VMworld Hackathon 2017
# www.virtuallyghetto.com
# Deployment of vRealize Operations Manager 6.0 (vROps)

### NOTE: SSH can not be enabled because hidden properties do not seem to be implemented in Get-OvfConfiguration cmdlet ###

### NOTE: Reused code from pod-deploy.ps1
### Start
# Get the folder location
$ScriptLocation = Split-Path -Parent $PSCommandPath
# Import the JSON Config File
$podConfig = (get-content $($configFile) -Raw) | ConvertFrom-Json
### End

# Load OVF/OVA configuration into a variable
$ovffile  = "$($ScriptLocation)\$($podConfig.sources.vROpsAppliance)"
####$ovffile = "E:\automation\vRealize-Operations-Manager-Appliance-6.0.1.2523163_OVF10.ova"

$ovfconfig = Get-OvfConfiguration $ovffile

# vSphere Cluster + VM Network configurations
$Cluster = $podConfig.target.cluster
$VDS = $podConfig.vcsa.distributedSwitch
$VDSPG = $podConfig.target.portgroup
$VCServer = $podConfig.target.server
$VMName = $podConfig.vrops.name

$VMHost = Get-Cluster $Cluster | Get-VMHost | Sort MemoryGB | Select -first 1
$Datastore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1
try {
    ## Try get vDS
	## Tosses an error if it cant locate vDS, but will try load standard switch
    $Network = Get-VDPortgroup -VDSwitch $VDS -Name $VDSPG -Server $VCServer
}
catch {
    ## Load standard portgroup (lab setup did not include vDS)
    $Network = Get-vmHost $VMHost | Get-VirtualPortGroup -name $VDSPG
}
# Fill out the OVF/OVA configuration parameters

# xsmall,small,medium,large,smallrc,largerc
$ovfconfig.DeploymentOption.value = $podConfig.vrops.deploymentSize

# IP Address
$ovfConfig.vami.vRealize_Operations_Manager_Appliance.ip0.value = $podConfig.vrops.ip

# Gateway
$ovfConfig.vami.vRealize_Operations_Manager_Appliance.gateway.value = $podConfig.target.network.gateway

# Netmask
$ovfConfig.vami.vRealize_Operations_Manager_Appliance.netmask0.value = $podConfig.target.network.netmask

# DNS
$ovfConfig.vami.vRealize_Operations_Manager_Appliance.DNS.value = $podConfig.target.network.dns

# vSphere Portgroup Network Mapping
$ovfconfig.NetworkMapping.Network_1.value = $Network

# IP Protocol
$ovfconfig.IpAssignment.IpProtocol.value = $podConfig.target.network.ipprotocol

# Timezone
$ovfconfig.common.vamitimezone.value = $podConfig.target.network.timezone

# Deploy the OVF/OVA with the config parameters
Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin
get-vm -name $VMName | start-vm