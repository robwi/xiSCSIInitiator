$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xiSCSIInitiatorHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$TargetPortalAddress,

		[parameter(Mandatory = $true)]
		[System.String]
		$NodeAddress
	)

    if($TargetPortal = Get-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -ErrorAction SilentlyContinue)
    {
        $TargetPortalPortNumber = $TargetPortal.TargetPortalPortNumber
        $InitiatorPortalAddress = $TargetPortal.InitiatorPortalAddress
        Write-Verbose -Message "Found target portal at portal address: $TargetPortalAddress with port: $TargetPortalPortNumber."
    }
    else
    {
        Write-Verbose -Message "Didn't find a target portal at portal address: $TargetPortalAddress."
    }

    $FullNodeAddress = (Get-IscsiTarget | Where-Object {$_.NodeAddress -like $NodeAddress}).NodeAddress
    if(!($FullNodeAddress))
    {
        Write-Verbose -Message "Didn't find a target at node address $NodeAddress at target portal address: $TargetPortalAddress."
    }

    if($iSCSISession = (Get-IscsiSession | Where-Object {$_.TargetNodeAddress -eq $FullNodeAddress}))
    {
        $IsPersistent = $iSCSISession.IsPersistent
        Write-Verbose -Message "Found iSCSI session for node address: $FullNodeAddress with IsPersistent: $IsPersistent."
    }
    else
    {
        Write-Verbose -Message "Did'nt find iSCSI session for node address: $FullNodeAddress."   
    }

	$returnValue = @{
		TargetPortalAddress = $TargetPortalAddress
		TargetPortalPortNumber = $TargetPortalPortNumber
        InitiatorPortalAddress = $InitiatorPortalAddress
		NodeAddress = $FullNodeAddress
		IsPersistent = $IsPersistent
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$TargetPortalAddress,

		[System.UInt16]
		$TargetPortalPortNumber = 3260,

        [System.String]
        $InitiatorPortalAddress,

		[parameter(Mandatory = $true)]
		[System.String]
		$NodeAddress,

		[System.Boolean]
		$IsPersistent,

		[System.Boolean]
        $IsMultipathEnabled
	)

    $TargetPortal = Get-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -ErrorAction SilentlyContinue
    if(!($TargetPortal))
    {
        if($PSBoundParameters.ContainsKey('InitiatorPortalAddress'))
        {
            Write-Verbose -Message "Creating a new target portal at portal address: $TargetPortalAddress and port: $TargetPortalPortNumber and initiator address: $InitiatorPortalAddress."
            $TargetPortal = New-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -TargetPortalPortNumber $TargetPortalPortNumber -InitiatorPortalAddress $InitiatorPortalAddress -ErrorAction Stop
        }
        else
        {
            Write-Verbose -Message "Creating a new target portal at portal address: $TargetPortalAddress and port: $TargetPortalPortNumber."
            $TargetPortal = New-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -TargetPortalPortNumber $TargetPortalPortNumber -ErrorAction Stop
        }
    }
    else
    {
        if($PSBoundParameters.ContainsKey('InitiatorPortalAddress'))
        {
            Write-Verbose -Message "Updating the target portal at portal address: $TargetPortalAddress and port: $TargetPortalPortNumber and initiator address: $InitiatorPortalAddress."
            $TargetPortal = Update-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -TargetPortalPortNumber $TargetPortalPortNumber -InitiatorPortalAddress $InitiatorPortalAddress -ErrorAction Stop
        }
        else
        {
            Write-Verbose -Message "Updating the target portal at portal address: $TargetPortalAddress and port: $TargetPortalPortNumber and initiator address: $InitiatorPortalAddress."
            $TargetPortal = Update-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -TargetPortalPortNumber $TargetPortalPortNumber -ErrorAction Stop
        }
    }

    $FullNodeAddress = (Get-IscsiTarget | Where-Object {$_.NodeAddress -like $NodeAddress}).NodeAddress
    if(!($FullNodeAddress))
    {
        throw New-TerminatingError -ErrorType NoiSCSITargetFound -ErrorCategory InvalidResult
    }

    $targets = Get-IscsiTarget
    foreach ($target in $targets)
    {
        if ($target.NodeAddress -eq $FullNodeAddress)
        {            
            if ($target.IsConnected -ne $true)
            {
                if($PSBoundParameters.ContainsKey('InitiatorPortalAddress'))
                {
                    Write-Verbose -Message "Connecting to iSCSI target node address: $FullNodeAddress with target portal address: $TargetPortalAddress and initiator address: $InitiatorPortalAddress."
                    Connect-IscsiTarget -NodeAddress $FullNodeAddress -InitiatorPortalAddress $InitiatorPortalAddress -IsPersistent:$IsPersistent -IsMultipathEnabled:$IsMultipathEnabled -ErrorAction Stop
                }
                else
                {
                    Write-Verbose -Message "Connecting to iSCSI target node address: $FullNodeAddress with target portal address: $TargetPortalAddress."
                    Connect-IscsiTarget -NodeAddress $FullNodeAddress -IsPersistent:$IsPersistent -IsMultipathEnabled:$IsMultipathEnabled -ErrorAction Stop
                }
            }
            else
            {
                Write-Verbose -Message "iSCSI target node address: $FullNodeAddress and portal address: $TargetPortalAddress is already connected."
            }
        }
    }

    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType TestFailedAfterSet -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$TargetPortalAddress,

		[System.UInt16]
		$TargetPortalPortNumber = 3260,

        [System.String]
        $InitiatorPortalAddress,

		[parameter(Mandatory = $true)]
		[System.String]
		$NodeAddress,

		[System.Boolean]
		$IsPersistent,

		[System.Boolean]
        $IsMultipathEnabled
	)

    if($TargetPortal = Get-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -ErrorAction SilentlyContinue)
    {
        $NodeAddress = (Get-IscsiTarget | Where-Object {$_.NodeAddress -like $NodeAddress}).NodeAddress
        if((Get-IscsiSession -ErrorAction SilentlyContinue | Where-Object {$_.TargetNodeAddress -eq $NodeAddress}).IsConnected -eq "True")
        {
            $result = $true
        }
        else
        {
            $result = $false
        }
    }
    else
    {
        $result = $false
    }

	$result
}


Export-ModuleMember -Function *-TargetResource

