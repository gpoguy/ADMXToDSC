# ADMXToDSC
PowerShell script to convert GPO-based Admin Template settings into a Desired State Configuration Document

Requires Microsoft GroupPolicy module be installed in order to run

Updated on 6-9-2016 to be an advanced function (thank you github.com/kevsully!) 
Added tweaks to better support converting "non-standard" policy areas that use registry.pol, including WIndows Firewall and Applocker/Software Restriction Policies
