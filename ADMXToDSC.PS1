#This script requires MS GroupPolicy module be installed to run
param
(
    [Parameter(Mandatory=$true)]
    [string]$gpoName,
    [Parameter(Mandatory=$true)]
    [string] $outputFolder
)


function ADMtoDSC

{
    param
    ( 
       [String] $gpo,
       [String] $path


    )


    $policies = Recurse_PolicyKeys -key "HKLM\Software\Policies" -gpo $gpo

    $policies += Recurse_PolicyKeys -key "HKLM\Software\Microsoft\Windows NT\CurrentVersion" -gpo $gpo
    #build the DSC configuration doc
    GenConfigDoc -path $path -gpo $gpo -policies $policies
}

function Recurse_PolicyKeys
{
    param
    (
        [string]$key,
        [string]$gpoName
    )
    $current = Get-GPRegistryValue -Name $gpo -Key $key
    foreach ($item in $current)
    {
        if ($item.ValueName -ne $null)
        {
            [array]$returnVal += $item
        }
        else
        {
            Recurse_PolicyKeys -Key $item.FullKeyPath -gpoName $gpo
        }
    }
    return $returnVal
}

function GenConfigDoc
{
    param
    (
        [string] $path,
        [string] $gpo,
        [array] $policies
    )
    #parse the spaces out of the GPO name, since we use it for the Configuration name
    $gpo = $gpo -replace " ","_"
    $outputFile = "$path\$gpo.ps1"
    "Configuration `"$gpo`"" | out-file -FilePath $outputFile
    '{' | out-file -FilePath $outputFile -Append
    'Node localhost' | out-file -FilePath $outputFile -Append
    '  {' | out-file -FilePath $outputFile -Append
    foreach ($regItem in $policies)
    {
        if ($regItem.FullKeyPath -eq $null) #throw away any blank entries
        {
             continue
        }

        #now build the resources
        "    Registry `"" + $regItem.ValueName + "`""| out-file -FilePath $outputFile -Append
        '    {' | out-file -FilePath $outputFile -Append
        "      Ensure = `"Present`"" | out-file -FilePath $outputFile -Append
        "      Key = `""+ $regItem.FullKeyPath + "`""| out-file -FilePath $outputFile -Append
        "      ValueName = `"" + $regItem.ValueName + "`"" | out-file -FilePath $outputFile -Append
        "      ValueType = `"" +$regItem.Type + "`"" | out-file -FilePath $outputFile -Append
        "      ValueData = `"" +$regItem.Value + "`""| out-file -FilePath $outputFile -Append
        '    }' | out-file -FilePath $outputFile -Append
    }
    '  }' | out-file -FilePath $outputFile -Append
    '}' | out-file -FilePath $outputFile -Append
    $gpo | out-file -FilePath $outputFile -Append
}

ADMToDSC -gpo $gpoName -path $outputFolder 
