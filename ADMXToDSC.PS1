<#
.Synopsis
   ConvertTo-ADMXtoDSC allows you to get registry keys and values configured within the registry.pol file in existing GPOs
   and use that information to create DSC docuemnts.
.DESCRIPTION
   Group Policy Objects have been created, managed, configured, re-configured, deleted,
   backed up, imported, exported, inspected, detected, neglected and rejected for many years. 
   Now with the advent of Desired State Configuration (DSC) ensuring that the work previously 
   done with regards to configuring registry policy is not lost, is key. ConvertTo-ADMXtoDSC is a cmdlet 
   (advanced function) that was created to address this sceanario. The ConvertTo-ADMXtoDSC cmdlet
   requires the GroupPolicy PowerShell Module. The GP cmdlets are avaialbe on machines where 
   the GPMC is installed. The <gponame>.ps1 file will be opened in the PowerShell ISE as a
   convenience.
.EXAMPLE
   ConvertTo-ADMXtoDSC -GPOName <gpo> -OutputFolder <folder where to create DSC .ps1 file>
.EXAMPLE
   GP2DSC -GPOName <GPO> -OutputFolder <folder>
.LINK
    Http://www.github.com/gpoguy
#>
function ConvertTo-ADMXtoDSC
{
    # add additional cmdletBinding information to make the experience more robust.
    [CmdletBinding()]
    [Alias("GP2DSC")]
    [OutputType([int])]
    # possible new scenarios... optional open in ISE when complete. 
    # optional create of .mof file, including target test machine. This scenario would 
    # be an e2e test where the GPO is selected, Registry data is converted to .ps1 config
    # the configuration is called and .mof is created and DSC configuration is started targeting
    # a test machine.
    Param
    # possibly re-work parameter names.
        ([Parameter(Mandatory=$true)]
        [string]$gpoName,
        [Parameter(Mandatory=$true)]
        [string] $outputFolder
    )

    Process
    {
        #this hash table holds valuename, which we use to name registry resources--guarantees that they are unique
        $valueNameHashTable = @{}
        function ADMtoDSC
        {
            param
            ( 
               [String] $gpo,
               [String] $path
            )
            #get policy keys for two main per-computer keys where policy is stored
            #NOTE that this script could be extended to add HKCU per-user keys but as of today--no good mechanisms exist
            #for triggering per-user configuration in DSC
            $policies = Recurse_PolicyKeys -key "HKLM\Software\Policies" -gpo $gpo
            

            $policies += Recurse_PolicyKeys -key "HKLM\Software\Microsoft\Windows NT\CurrentVersion" -gpo $gpo
            
            # build the DSC configuration doc
            GenConfigDoc -path $path -gpo $gpo -policies $policies
            # add error/debug and verbose.
        }

        function Recurse_PolicyKeys
        # This function goes through the registry.pol data and finds entries associated with the 
        # two policy hives mentioned above. Consider rename of the function to be more modular and 
        # powershell'ish
        {
            param
            (
                [string]$key,
                [string]$gpoName
            )
            
            # Get-GPRegistryValue is from the GroupPolicy PowerShell module.
            $current = Get-GPRegistryValue -Name $gpo -Key $key  -ErrorAction SilentlyContinue
            if ($current -eq $null) #means we didn't get a reference to the key being called--probably beause there's no pol settings under it
            {
                return
            }
            foreach ($item in $current)
            {
                if ($item.ValueName -ne $null)
                {
                    [array]$returnVal += $item
                }
                else
                {
                    #this handles the case where we're on a container (i.e. keypath) that doesn't have a value
                    Recurse_PolicyKeys -Key $item.FullKeyPath -gpoName $gpo
                }
            }
            return $returnVal
            
        }

        function GenConfigDoc
        # consider rename of function - New-DSCDoc
        # add verbose output, error handling and debugging
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
            "Configuration `"$gpo`"" | out-file -FilePath $outputFile -Encoding unicode
            '{' | out-file -FilePath $outputFile -Append -Encoding unicode
            "   Import-DscResource –ModuleName PSDesiredStateConfiguration" | out-file -Append -FilePath $outputFile -Encoding unicode
            'Node localhost' | out-file -FilePath $outputFile -Append -Encoding unicode
            '  {' | out-file -FilePath $outputFile -Append -Encoding unicode
            foreach ($regItem in $policies)
            {
                if ($regItem.FullKeyPath -eq $null) #throw away any blank entries
                {
                     continue
                }
                #this next bit guarantees a unique DSC resource name by adding each registry resource name to a hashtable. If found, we increment the key index and append to resource name
                $resourceName = ""
                if ($valueNameHashTable.ContainsKey($regItem.ValueName))
                {
                    $valueNameHashTable[$regItem.ValueName] = $valueNameHashTable[$regItem.ValueName]+1
                    $resourceName = $regItem.ValueName+$valueNameHashTable[$regItem.ValueName]
                }
                else
                {
                    $valueNameHashTable.Add($regItem.ValueName,0)
                    $resourceName = $regItem.ValueName
                }
                # now build the resources
                # exploring other ways to create the resource info.
                # added unicode encoding to valuename and data to support that type for certain policies (e.g. SRP/Applocker)
                "    Registry '" + $resourceName + "'"| out-file -FilePath $outputFile -Append -Encoding unicode
                '    {' | out-file -FilePath $outputFile -Append -Encoding unicode
                "      Ensure = 'Present'" | out-file -FilePath $outputFile -Append -Encoding unicode
                "      Key = '"+ $regItem.FullKeyPath + "'"| out-file -FilePath $outputFile -Append -Encoding unicode
                "      ValueName = '" + $regItem.ValueName + "'" | out-file -FilePath $outputFile -Append -Encoding unicode
                "      ValueType = '" +$regItem.Type + "'" | out-file -FilePath $outputFile -Append -Encoding unicode
                # need to trim any nul characters from ValueData (mostly an Applocker issue)
                $trimValue = $regItem.Value.ToString().Trim("`0")
                "      ValueData = '" +$trimValue + "'"| out-file -FilePath $outputFile -Append -Encoding unicode
                '    }' | out-file -FilePath $outputFile -Append -Encoding unicode
            }
            '  }' | out-file -FilePath $outputFile -Append -Encoding unicode
            '}' | out-file -FilePath $outputFile -Append -Encoding unicode
            $gpo | out-file -FilePath $outputFile -Append -Encoding unicode
        }
        ADMToDSC -gpo $gpoName -path $outputFolder
        #ISE "$outputfolder\$gponame.ps1"
    }
}

