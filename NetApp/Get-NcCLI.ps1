Function Get-NcCLI{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias('Filer','Node')]
        [String[]]$Controller,

        [Parameter(Mandatory=$False)]
        [ValidateSet("admin","advanced","diag")]
        [String]$priviledge="admin",

        [Parameter(Mandatory=$False)]
        [Switch]$logonly,

        [Parameter(Mandatory=$False)]
        [Switch]$includehidden
    )
    Begin{
        $hiddenoptions = ("statistics-v1",
                          "reallocate",
                          "debug")
        $date = Get-Date -uformat "%Y%m%d"
        Function ParseNcSSH($SSHvalue){
            $commands = foreach($line in ($SSHvalue.value.split("`n") | Where-Object length -gt 1)){
                if($line.tochararray()[0..3] -ne " "){
                    if(($line -split ' {2,}')[1] -like "command is complete*" -or ($line -split ' {2,}')[1].chars(0) -match '\W'){
                    }else{
                        ($line -split ' {2,}')[1]
                    }
                }
            }
        return $commands
        }

    }
    Process{

        Function RecurseNcCLI{
            Param ([string]$filepath, [string]$priv, [string]$object = "", [int]$level = 0)

            $x = Invoke-NcSsh -command "set $priv;$object ?"
            $p = ParseNcSSH $x
            foreach($i in $p){
                $item = $i.replace(">","")
                if(!$logonly){Write-Output "$object $item"}
                Add-Content $filepath -value "$object $item"
                Start-Sleep -Milliseconds 250
                if(($item -ne "up")  -and ($item -ne 'Press "?" or Tab for help.')){
                    $y = Invoke-NcSsh -command "set $priv;$object $item ?"
                    #don't recurse man - infinite loop
                    if((ParseNcSSH $y).count -eq 0 -or ($item -eq "man") -or ($item -like "Error:*")){
                        $y.value.split("`r`n") | ForEach-Object{if($_.length -gt 0){if(!$logonly){Write-Output "     $_"};Add-Content $filepath -value "     $_"}}
                    }else{
                        $new = "$object $item"
                        RecurseNcCLI $filepath $priv $new ($level + 1)
                    }
                }
            }
        }

        foreach($C in $Controller){
            Connect-NcController $C > $null
            $version = (Get-NcSystemVersionInfo).VersionTupleV.ToString()
            $outfile = "NetApp-CLI-$C-$version-$priviledge-$date.txt"
            RecurseNcCLI $outfile $priviledge
            if($includehidden){
                foreach($hidden in $hiddenoptions){
                    RecurseNcCLI $outfile $priviledge $hidden 1
                }
            }
        }
    }
}