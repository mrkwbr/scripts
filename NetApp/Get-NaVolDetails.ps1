Function Get-NaVolDetails{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias('Filer','Node')]
        [String[]]$Controller
    )
    Begin{
        $Results = @()
        $RunDate = (get-date).ToShortDateString()
    }
    Process{
        foreach($C in $Controller){
            $date = get-date
            connect-nacontroller $C > $null
            $license = Get-NaLicense
            if (($license | where -Property service -eq "sv_ontap_pri").islicensed){
                $svstatus = Get-NaSnapvaultPriStatus
                $svsourcehash = $svstatus | where -property sourcesystem -eq "$C" | group -Property sourcepath -AsHashTable
                $svdesthash = $svstatus | where -property destinationsystem -eq "$C" | group -Property destinationpath -AsHashTable
            }
            else{
                $svstatus = $false
                $IsSnapvaultDest = $false
                $IsSnapvaultSource = $false
                if($svdesthash){clv svdesthash}
                if($svsourcehash){clv svsourcehash}
            }
            if (($license | where -Property service -eq "snapmirror").islicensed){
                $smstatus = Get-NaSnapmirror
                $smsourcehash = $smstatus | group -Property Source -AsHashTable
                $smdesthash = $smstatus | group -Property Destination -AsHashTable
            }
            else{
                $smstatus = $false
            }
            $cifs = Get-NaCifsShare | group -Property MountPoint -AsHashTable
            $nfs = Get-NaNfsExport | group -Property ActualPathname -AsHashTable
            $qtree = Get-NaQtree | group -Property Volume -AsHashTable
            $efficiency = Get-NaEfficiency -Hashtable
            foreach ($vol in get-navol){
                $sizesaved = $null
                $sizeshared = $null
                $percentagesaved = $null
                $snapvaultsource = $null
                $snapvaultdest = $null
                $svsource = $null
                $svdest = $null
                $IsSnapvaultDest = $false
                $IsSnapvaultSource = $false
                $volefficiency = $efficiency.item("$($vol.name)")
                if($volefficiency.snapusage.reserve -gt 0){
                    $SnapUsedPercent = 100 * ($volefficiency.snapusage.used / $volefficiency.snapusage.reserve)
                    $SnapReservePercent = 100 * ($volefficiency.snapusage.reserve / ($volefficiency.snapusage.reserve + $vol.sizetotal))
                }
                else{
                    $SnapUsedPercent = 0
                    $SnapReservePercent = 0
                }
                if($smstatus){
                    $smsource = $smsourcehash.item("$c`:$($vol.name)")
                    if ($smsource){$IsSnapmirrorSource = $true}else{$IsSnapmirrorSource = $false}
                    $smdest = $smdesthash.item("$c`:$($vol.name)")
                    if ($smdest){$IsSnapmirrorDest = $true}else{$IsSnapmirrorDest = $false}
                    $sm = $smsource + $smdest
                }
                if($svstatus){
                    if($svsourcehash.count -gt 0){
                        $svsource = $svsourcehash.item("/vol/$($vol.name)")
                        $Snapvaultdest = $svsource.secondary 
                        $SnapvaultSource = $svsource.primary
                    }
                    if ($svsource){$IsSnapvaultSource = $true}else{$IsSnapvaultSource = $false}
                    if($svdesthash.count -gt 0){
                        $svdest = $svdesthash.item("/vol/$($vol.name)/$($vol.name)")
                        $Snapvaultdest = $svdest.secondary 
                        $SnapvaultSource = $svdest.primary
                    }
                    if ($svdest){$IsSnapvaultDest = $true}else{$IsSnapvaultDest = $false}
                }
# CIFS share enumeration will break for any volume named "vol"
                $CIFSShare = $cifs.keys | ? {$_.split('/') -eq $($vol.name)} | %{$cifs.item($_)}
                if($($vol.name) -eq "vol0"){
                    $CIFSShare += $cifs.keys | ? {$_.split('/')[1] -ne "vol"} | %{$cifs.item($_)}
                }
                if($CIFSShare){$IsCIFS = $true}else{$IsCIFS = $false}
                if($nfs){
                    $NFSExport = $nfs.keys | ? {$_.split('/') -eq $($vol.name)} | %{$nfs.item($_)}
                }
                else{
                    $NFSExport = $null
                }
                if($NFSExport){$IsNFS = $true}else{$IsNFS = $false}
                $q = $qtree.item($($vol.name))
                $SecurityStyle = ($q | where qtree -eq "").SecurityStyle
                $OpLocks = ($q | where qtree -eq "").OpLocks
                if($q.count -gt 1){
#                    $q | where qtree -ne ""
                }else{
                    
                }
                $Prop=[ordered]@{
                    'RunDate' = $RunDate -as [datetime]
                    'Controller' = $C
                    'Volume' = $vol.name
                    'VolumeUUID' = $vol.Uuid
                    'Aggregate' = $vol.containingaggregate
                    'SecurityStyle' = $SecurityStyle
                    'OpLocks' = $OpLocks
                    'FilesUsed' = $vol.filesused -as [int]
                    'SizeUsed' = $vol.sizeused -as [int64]
                    'SizeUsedGB' = $vol.sizeused / 1gb -as [int]
                    'SizeTotal' = $vol.sizetotal -as [int64]
                    'SizeTotalGB' = $vol.sizetotal / 1gb -as [int]
                    'PercentUsed' = $vol.percentageused -as [int]
                    'SizeSaved' = $volefficiency.returns.total -as [int64]
                    'SizeSavedGB' = $volefficiency.returns.total / 1gb -as [int]
                    'DedupeSaved' = $volefficiency.returns.Dedupe -as [int64]
                    'DedupeSavedGB' = $volefficiency.returns.Dedupe / 1gb -as [int]
                    'CompressionSaved' = $volefficiency.returns.Compression -as [int64]
                    'CompressionSavedGB' = $volefficiency.returns.Compression / 1gb -as [int]
                    'SnapSaved' = $volefficiency.returns.Snapshot -as [int64]
                    'SnapSavedGB' = $volefficiency.returns.Snapshot / 1gb -as [int]
                    'EfficiencyPercent' = $volefficiency.EfficiencyPercentage -as [int]
                    'SnapReserveUsed' = $volefficiency.snapusage.used -as [int64]
                    'SnapReserveUsedGB' = $volefficiency.snapusage.used / 1gb -as [int]
                    'SnapReserveTotal' = $volefficiency.snapusage.reserve -as [int64]
                    'SnapReserveTotalGB' = $volefficiency.snapusage.reserve / 1gb -as [int]
                    'SnapReserveUsedPercent' = $SnapUsedPercent -as [int]
                    'SnapReservePercent' = $SnapReservePercent -as [int]
                    'CIFSShare' = $CIFSShare.Sharename
                    'CIFSShareExtended' = $CIFSShare
                    'NFSExport' = $NFSExport.Pathname
                    'SnapmirrorDest' = $sm.Destination
                    'SnapmirrorSource' = $sm.Source
                    'SnapvaultDest' = $snapvaultdest
                    'SnapvaultSource' = $snapvaultsource
                    'IsCIFS' = $isCIFS
                    'IsNFS' = $isNFS
                    'IsSnapmirrorDest' = $IsSnapmirrorDest
                    'IsSnapmirrorSource' = $IsSnapmirrorSource
                    'IsSnapvaultDest' = $IsSnapvaultDest
                    'IsSnapvaultSource' = $IsSnapvaultSource
                    'VolumeExtended' = $vol
                    'QtreeExtended' = $q
                    'NFSExportExtended' = $NFSExport
                    'EfficiencyExtended' = $volefficiency
                    'date' = $date
                }
                $Obj=New-Object -TypeName PSObject -Property $Prop
                $Results += $Obj
            }
        }
    }
    End{
        #globally add aliasproperty
        $results | add-member -MemberType AliasProperty -name Used -value SizeUsedGB
        $results | add-member -MemberType AliasProperty -name Total -value SizeTotalGB
        $results | add-member -MemberType AliasProperty -name VolumeName -value Volume
        $results | add-member -MemberType AliasProperty -name Uuid -value VolumeUUID
        $results | add-member -MemberType AliasProperty -name Filer -value Controller
        $results | add-member -MemberType AliasProperty -name Node -value Controller
        $results | add-member -MemberType AliasProperty -name Security -value SecurityStyle
        Write-Output $Results
    }
}
