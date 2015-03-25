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
        [String]$priviledge="admin"
    )
    Begin{

        $date = Get-Date -uformat "%Y%m%d"
        Function ParseNcSSH($SSHvalue){
            $commands = foreach($line in ($SSHvalue.value.split("`n") | where length -gt 1)){
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

        Function RecurseNcCLI {
            Param ([string]$filepath, [string]$priv, [string]$object = "", [int]$level = 0)

            $x = invoke-ncssh -command "set $priv;$object ?"
            $p = ParseNcSSH $x
            foreach($i in $p){
                $item = $i.replace(">","")
                Write-Output "$object $item" | Tee-object -filepath $filepath -Append
                sleep 1
                $y = invoke-ncssh -command "set $priv;$object $item ?"
                #don't recurse man - infinite loop
                if((ParseNcSSH $y).count -eq 0 -or ($item -eq "man") -or ($item -like "Error:*")){
                    $y.value.split("`n") | %{if($_.length -gt 0){Write-Output "     $_" | Tee-object -filepath $filepath -Append}}
                }else{
                    $new = "$object $item"
                    RecurseNcCLI $filepath $priv $new ($level + 1)
                }
            }
        }

        foreach($C in $Controller){
            connect-nccontroller $C > $null
            $version = (get-ncsystemversioninfo).VersionTupleV.ToString()
            $outfile = "netapp-cli-$C-$version-$priviledge-$date.txt"
            RecurseNcCLI $outfile $priviledge
        }
    }
}