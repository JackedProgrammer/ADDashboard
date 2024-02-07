$forestName="jacked.ca"
$fileLocation="C:\Users\administrator\Documents\Scripts\ADDashboard\addashboard.html"

$forest=Get-ADForest -Identity $forestName

$domains=$forest.Domains
$globalCatalogs=$forest.GlobalCatalogs

$allDomainInfo=[System.Collections.ArrayList]@()

foreach($domain in $domains){
    $domainControllers=Get-ADDomainController -Server $domain -Filter *
    $defaultPasswordPolicy = Get-ADDefaultDomainPasswordPolicy -Server $domain
    $fineGrainedPolicies = Get-ADFineGrainedPasswordPolicy -Server $domain -Filter *
    $userProperties=@('accountexpirationdate','accountlockouttime','created','department','description','displayname','emailaddress','employeeid','enabled','lastlogondate','lockedout','office','passwordlastset','samaccountname','title')
    $computerProperties=@('createTimeStamp','Description','DistinguishedName','DNSHostName','Enabled','IPv4Address','Name','OperatingSystem','OperatingSystemServicePack','OperatingSystemVersion')

    $users=Get-ADUser -Filter * -Properties $userProperties -Server $domain 
    $computers=Get-ADComputer -Filter * -Properties $computerProperties -server $domain

    if($domain -eq "jacked.ca"){
        $ousToMonitor=@('OnHoldForDeletion','NewYork')
    }

    $groupsToMonitor=@('Domain Admins','Enterprise Admins','NetworkAdmin','WebAdmin')
    $groups=@()

    foreach($groupToMonitor in $groupsToMonitor){
        try{
            $ADGroup=Get-ADGroup -Identity $groupToMonitor -Server $domain -Properties *

            $groupMembers=@"
"@

            foreach($member in $adgroup.members){
                $groupMembers=@"
$groupMembers
$member
"@
            }

            $entry=New-Object -TypeName PSCustomObject
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Name" -Value $ADGroup.Name
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Scope" -Value $ADGroup.GroupScope
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Category" -Value $ADGroup.GroupCategory
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Last Modified" -Value $ADGroup.Modified
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "MemberCount" -Value $ADGroup.Members.Count
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Members" -Value $groupMembers

            $groups+=$entry
        }catch{

        }
    }



    $entry=New-Object -TypeName PSCustomObject
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Domain" -Value $domain
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "DomainControllers" -Value $domainControllers
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "DefaultDomainPasswordPolicy" -Value $defaultPasswordPolicy
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "DomainFineGrainedPasswordPolicies" -Value $fineGrainedPolicies
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Users" -Value $users
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Computers" -Value $computers
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Groups" -Value $groups
    Add-Member -InputObject $entry -MemberType NoteProperty -Name "OUsToMonitor" -Value $ousToMonitor

    $allDomainInfo.add($entry)
}

$allDomainControllersTable = $allDomainInfo.DomainControllers | select name,IPv4Address,domain,hostname,enabled,operatingsystem,forest

New-HTML -Online -TitleText "Active Directory Dashboard" -FilePath $fileLocation -ShowHTML {
    New-HTMLTab -Name "Forest" {
        New-HTMLSection -Invisible {
            New-HTMLSection -HeaderText "Forest Information" {
                New-HTMLPanel -Margin "10px" {
                    "<p>Forest : $($forest.Name)</p>"
                    "<p>Forest Functional Level : $($forest.ForestMode)</p>"
                    "<p>Domains :</p>"
                    "<ul>"
                    foreach($domain in $domains){
                        "<li>$($domain)</li>"
                    }
                    "</ul>"
                    "<p>Root Domain : $($forest.RootDomain)</p>"
                    "<p>Global Catalogs :</p>"
                    "<ul>"
                    foreach($catalog in $globalCatalogs){
                        "<li>$($catalog)</li>"
                    }
                    "</ul>"
                }
            }
            New-HTMLSection -HeaderText "Domain Controllers" {
                New-HTMLPanel -Invisible {
                    Table -DataTable $allDomainControllersTable -HideFooter -HideButtons
                }
            }
        }
    }
    foreach($domain in $allDomainInfo){
        New-HTMLTab -Name "$($domain.Domain)" {
            New-HTMLSection -HeaderText "Domain Controllers" {
                New-HTMLPanel -Invisible {
                    table -DataTable $($domain | select -ExpandProperty DomainControllers) -HideFooter -HideButtons
                }
            }
            New-HTMLSection -HeaderText "Password Policies" -Invisible {
                New-HTMLSection -HeaderText "Default Domain Password Policy" {
                    New-HTMLPanel -Invisible {
                        $defaultPasswordPolicyTable=@{}
                        $($domain | select -ExpandProperty DefaultDomainPasswordPolicy | select ComplexityEnabled,LockoutDuration,LockoutObservationWindow,LockoutThreshold,MaxPasswordAge,MinPasswordAge,MinPasswordLength,PasswordHistoryCount,ReversibleEncryptionEnabled).psobject.properties | foreach{$defaultPasswordPolicyTable[$_.Name]=$_.value}
                        Table -DataTable $defaultPasswordPolicyTable -DefaultSortOrder Ascending -DefaultSortColumn name -HideFooter -HideButtons
                    }
                }
                New-HTMLSection -HeaderText "Domain Fine Grained Password Policies" {
                    New-HTMLPanel -Invisible {
                        Table -DataTable $($domain | select -ExpandProperty DomainFineGrainedPasswordPolicies | select Name,ComplexityEnabled,LockoutDuration,LockoutObservationWindow,LockoutThreshold,MaxPasswordAge,MinPasswordAge,MinPasswordLength,PasswordHistoryCount,ReversibleEncryptionEnabled) -HideFooter -HideButtons
                    }
                }
            }
            New-HTMLSection -HeaderText "Users" -Invisible {
                $disabledUsers=$domain.Users | Where-Object enabled -eq $false
                
                $disabledUsersTable=$disabledUsers | Select-Object name,title,samaccountname,enabled,lastlogondate,distinguishedname

                $lockedOutUsers=$domain.Users | Where-Object lockedout -eq $true

                $lockedOutUsersTable=$lockedOutUsers | Select-Object name,accountlockouttime,title,office,samaccountname,enabled,lastlogondate,distinguishedname

                $expiredUsers=$domain.Users | Where-Object accountexpirationdate -ne $null | Where-Object accountexpirationdate -lt $(get-date)

                $expiredUsersTable=$expiredUsers | Select-Object name,accountexpirationdate,title,office,samaccountname,enabled,lastlogondate,distinguishedname


                New-HTMLSection -HeaderText "Disabled Users"{
                    New-HTMLPanel -Invisible {
                        Table -DataTable $disabledUsersTable -HideFooter -HideButtons
                    }
                }
                New-HTMLSection -HeaderText "Locked out Users"{
                    New-HTMLPanel -Invisible {
                        Table -DataTable $lockedOutUsersTable -HideFooter -HideButtons
                    }
                }
                New-HTMLSection -HeaderText "Expired Users"{
                    New-HTMLPanel -Invisible {
                        Table -DataTable $expiredUsersTable -HideFooter -HideButtons
                    }
                }
            }
            New-HTMLSection -HeaderText "Groups to Monitor" {
                New-HTMLPanel -Invisible {
                    Table -DataTable $domain.groups -HideFooter -HideButtons
                }
            }
            New-HTMLSection -HeaderText "Computers" {
                $computersTable=$domain.computers | select 'Name','OperatingSystem','OperatingSystemServicePack','OperatingSystemVersion','createTimeStamp','Description','distinguishedName','dnshostname','enabled','IPv4Address'

                New-HTMLPanel -Invisible {
                    Table -DataTable $computersTable -HideFooter -HideButtons
                }
            }
            New-HTMLSection -HeaderText "OUs to Monitor" {
                foreach($ou in $domain.OUsToMonitor){
                    $usersTable=$users | Where-Object distinguishedName -like "*$ou*" | Select-Object name,title,samaccountname,enabled,lastlogondate,distinguishedname
                    New-HTMLSection -HeaderText $ou {
                        New-HTMLPanel -Invisible {
                            Table -DataTable $usersTable -HideFooter -HideButtons
                        }
                    }
                }

                
            }
        }
    }
}
