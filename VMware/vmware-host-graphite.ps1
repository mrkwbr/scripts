#schtasks /create /RU <account> /sc hourly /mo 1 /tn "vmware-host-graphite1" /tr "powershell.exe -noprofile -windowstyle hidden -file <path>\vmware-host-graphite.ps1" /sd 02/23/2012 /st 19:00:00
#schtasks /create /RU <account> /sc hourly /mo 1 /tn "vmware-host-graphite2" /tr "powershell.exe -noprofile -windowstyle hidden -file <path>\vmware-host-graphite.ps1" /sd 02/23/2012 /st 19:30:00

# main variables 
$graphiteserver = "localhost"
$graphiteserverport = 2003
$sVCentre =      "localhost"
$arrMetrics =    "datastore.numberReadAveraged.average",
                 "datastore.numberWriteAveraged.average",
                 "datastore.totalReadLatency.average",
		 "datastore.totalWriteLatency.average"

function sendtographite ($metrics)
{
  $socket = new-object system.net.sockets.tcpclient
  $socket.connect($graphiteserver, $graphiteserverport)
  $stream = $socket.getstream()
  $writer = new-object system.io.streamwriter($stream)

  foreach($i in 0..($metrics.count-1)){
    $writer.writeline($metrics[$i])
  }

  $writer.flush()
  $writer.close()
  $stream.close()
  $socket.close()
}

add-pssnapin VMware.VimAutomation.Core -erroraction silentlycontinue
$now = (get-date).addminutes(-30)

if ($now.minute -ge 30){
$starttime = (Get-Date -year $now.year -month $now.month -day $now.day -Hour $now.hour -Minute 30 -Second 0)
}
else {
$starttime = (Get-Date -year $now.year -month $now.month -day $now.day -Hour $now.hour -Minute 0 -Second 0)
}

[void](Connect-VIServer $sVCentre -erroraction silentlycontinue)
$arrHosts = Get-VMHost | where-object {$_.PowerState -eq "PoweredOn"}

$datastores = @{}
$arrHosts | %{ $_.ExtensionData.Config.FileSystemVolume.MountInfo | %{
	$key = $_.MountInfo.Path.Split('/')[-1]
	if(!$datastores.ContainsKey($key)){
		$datastores[$key] = $_.Volume.Name
	}
} }

$stats = Get-Stat -Entity $arrHosts -Stat $arrMetrics -start ($starttime).addseconds(-1) -finish ($starttime).addseconds(1780) -realtime

$results = @{}
foreach ($stat in ($stats| sort entity,metricid,timestamp)){
  $result = "VMware.hosts." + $stat.entity.name.split(".")[0] + ".datastores." + $datastores[$stat.instance] + "." + $stat.metricid.split(".")[1] + " " + $stat.value + " " + (get-date(($stat.timestamp).touniversaltime()) -uformat "%s")
  $results.add($results.count, $result)
}

sendtographite $results