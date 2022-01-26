#TODO: 
#add multithread and proper displays
#add batch for multiple vm move
#add filtering on datagrid
#add connect option on each vmnic


Try {
    Add-PSSnapin NutanixCMDletsPSSnapin
} Catch {
    Write-Host "Error during Nutanix CMDlets"
    Read-Host "Press a key to exit..."
    exit
}
Try {
    Add-Type -AssemblyName PresentationFramework
} Catch {
    Write-Host "Error during loading WPF"
    Read-Host "Press a key to exit..."
    exit
}

$username = $($env:username.split(".")[0] + "@" + $env:USERDNSDOMAIN)
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window">
    <StackPanel x:Name="SPMain" Margin="5,5,5,5" Orientation="Vertical" HorizontalAlignment="Center">
        <StackPanel x:Name="ClustersInformations" Margin="0,0,0,0" Orientation="Horizontal" HorizontalAlignment="Center">
            <GroupBox Header="Source Cluster" Margin="5,5,5,5">
                <Grid Height="Auto">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
					<Grid.ColumnDefinitions>
						<ColumnDefinition MinWidth="100"/>
						<ColumnDefinition MinWidth="200"/>
						<ColumnDefinition MinWidth="200"/>
					</Grid.ColumnDefinitions>
					<Label x:Name="lblClusterSourceFQDN" Content="FQDN" Grid.Row="0" Grid.Column="0" />
					<Label x:Name="lblClusterSourceLogin" Content="Login" Grid.Row="1" Grid.Column="0"  />
					<Label x:Name="lblClusterSourcePassword" Content="Password" Grid.Row="2" Grid.Column="0" />
					<TextBox Name="txtBoxClusterSourceFQDN" Text="Your Primary Cluster FQDN" Grid.Row="0" Grid.Column="1" />
					<TextBox Name="txtBoxClusterSourceLogin" Text="$userName" Grid.Row="1" Grid.Column="1" />
					<PasswordBox Name="txtBoxClusterSourcePassword" PasswordChar="*" Grid.Row="2" Grid.Column="1" />
				    <Button Name="ButtonConnectSource" Margin="5,5,5,5" Width="auto" Content="Connect" Grid.Row="0" Grid.Column="2" />
                    <Label Name="lblClusterSourceInfo" Content="Not connected!" Grid.Row="2" Grid.Column="2" />
                </Grid>
            </GroupBox>
            <GroupBox Header="Destination Cluster" Margin="5,5,5,5">
                <Grid Height="Auto">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
					<Grid.ColumnDefinitions>
						<ColumnDefinition MinWidth="100"/>
						<ColumnDefinition MinWidth="200"/>
						<ColumnDefinition MinWidth="200"/>
					</Grid.ColumnDefinitions>
					<Label x:Name="lblClusterDestinationFQDN" Content="FQDN" Grid.Row="0" Grid.Column="0" />
					<Label x:Name="lblClusterDestinationLogin" Content="Login" Grid.Row="1" Grid.Column="0"  />
					<Label x:Name="lblClusterDestinationPassword" Content="Password" Grid.Row="2" Grid.Column="0" />
					<TextBox Name="txtBoxClusterDestinationFQDN" Text="Your Second Cluster FQDN" Grid.Row="0" Grid.Column="1" />
					<TextBox Name="txtBoxClusterDestinationLogin" Text="$username" Grid.Row="1" Grid.Column="1" />
					<PasswordBox Name="txtBoxClusterDestinationPassword" PasswordChar="*" Grid.Row="2" Grid.Column="1" />
				    <Button Name="ButtonConnectDestination" Margin="5,5,5,5" Width="auto" Content="Connect" Grid.Row="0" Grid.Column="2" />
                    <Label Name="lblClusterDestinationInfo" Content="Not connected!" Grid.Row="2" Grid.Column="2" />
                </Grid>
            </GroupBox>
        </StackPanel>
        <GroupBox Header="VM List" Margin="5,5,5,5">
            <DataGrid Name="VMListDataGrid" HorizontalAlignment="Left" Height="200" VerticalAlignment="Top" AutoGenerateColumns="False" SelectionMode="Single" CanUserAddRows="False" CanUserDeleteRows="False">
                <DataGrid.Columns>
                    <DataGridTextColumn Header="Name" Binding="{Binding vmName}" />
                    <DataGridTextColumn Header="Power State" Binding="{Binding powerState}"/>
                    <DataGridTextColumn Header="Host" Binding="{Binding hostName}"/>
                    <DataGridTextColumn Header="Description" Binding="{Binding description}"/>
                </DataGrid.Columns>            
            </DataGrid>
        </GroupBox>
        <StackPanel x:Name="PDInformations" Margin="0,0,0,0" Orientation="Horizontal" HorizontalAlignment="Center">
            <GroupBox Header="Protection Domain Source" Margin="5,5,5,5">
				<ComboBox Name="ComboBoxPDSource" SelectedIndex="0" SelectedValuePath="Content" IsEnabled="False" >
					<ComboBoxItem Content="None"></ComboBoxItem>
				</ComboBox>
            </GroupBox>
            <GroupBox Header="Protection Domain Destination" Margin="5,5,5,5">
				<ComboBox Name="ComboBoxPDDestination" SelectedIndex="0" SelectedValuePath="Content" >
					<ComboBoxItem  Content="None"></ComboBoxItem>
				</ComboBox>
            </GroupBox>
        </StackPanel>
        <StackPanel Name="SPNicInformations" Margin="0,0,0,0" Orientation="Vertical" HorizontalAlignment="Center">
        </StackPanel>
        <StackPanel Name="SPBottom" Margin="0,0,0,0" Orientation="Horizontal" HorizontalAlignment="Center">
            <GroupBox Header="Options" Margin="5,5,5,5">
                <CheckBox Name="CheckBoxPowerOn">Power on</CheckBox>
            </GroupBox>
            <StackPanel Name="SPButtons" Margin="0,0,0,0" Height="auto" Orientation="Horizontal" HorizontalAlignment="Center">
                <Button Name="ButtonGo" Margin="5,5,5,5" Width="auto" Content="GO" IsEnabled="False" />
                <Button Name="ButtonQuit" Margin="5,5,5,5" Width="auto"  Content="Quit"  />
            </StackPanel>
        </StackPanel>
    </StackPanel>
</Window>
"@
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)


#===========================================================================
# Store Form Objects In PowerShell
#===========================================================================
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $window.FindName($_.Name)}

$script:listNetworkSources = @()
$script:listNetworkDestination = @()
#Hashtable to control the status of OKButton
$OKButtonEnabled = @{
	"ConnexionSource" = $false
	"ConnexionDestination" = $false
}

$WPFButtonConnectSource.add_Click({
    Try {
        $connectionSource = connect-NutanixCluster -server $WPFtxtBoxClusterSourceFQDN.Text -password $WPFtxtBoxClusterSourcePassword.SecurePassword -username $WPFtxtBoxClusterSourceLogin.Text -ForcedConnection
        $WPFlblClusterSourceInfo.Content = "connected !"
        $WPFlblClusterSourceInfo.Foreground = "Green"
        $OKButtonEnabled.ConnexionSource = $true
        # Getting VM Source
        $WPFVMListDataGrid.Clear()
        foreach ($vm in get-ntnxvm -Servers $WPFtxtBoxClusterSourceFQDN.Text) {
            $WPFVMListDataGrid.AddChild($vm)
        }
        # Getting PD Sources
        foreach ($pd in Get-NTNXProtectionDomain -Servers $WPFtxtBoxClusterSourceFQDN.Text) {
            [System.Windows.Controls.ComboBoxItem]$newItem = new-object System.Windows.Controls.ComboBoxItem
            $newItem.Content = $pd.name
            $WPFComboBoxPDSource.AddChild($newItem)
        }
        # Getting Source networks
        $script:listNetworkSources = Get-NTNXNetwork -Servers $WPFtxtBoxClusterSourceFQDN.Text
        # Update GO and gridView Button
        $WPFButtonGo.IsEnabled = $WPFVMListDataGrid.IsEnabled = !($OKButtonEnabled.ContainsValue($false))
    } catch {
        $_
        $WPFlblClusterSourceInfo.Content = $_.FullyQualifiedErrorId
        $WPFlblClusterSourceInfo.Foreground = "Red"
        $OKButtonEnabled.ConnexionSource = $false
        $WPFButtonGo.IsEnabled = !($OKButtonEnabled.ContainsValue($false))
    }
})




$WPFButtonConnectDestination.add_Click({
    Try {
        $connectionDestination = connect-NutanixCluster -server $WPFtxtBoxClusterDestinationFQDN.Text -password $WPFtxtBoxClusterDestinationPassword.SecurePassword -username $WPFtxtBoxClusterDestinationLogin.Text -ForcedConnection
        $WPFlblClusterDestinationInfo.Content = "connected !"
        $WPFlblClusterDestinationInfo.Foreground = "Green"
        $OKButtonEnabled.ConnexionDestination = $true
        # Getting PD Destination
        foreach ($pd in $(Get-NTNXProtectionDomain -Servers $WPFtxtBoxClusterDestinationFQDN.Text | Where-Object {$_.active -eq $True})) {
            [System.Windows.Controls.ComboBoxItem]$newItem = new-object System.Windows.Controls.ComboBoxItem
            $newItem.Content = $pd.name
            $WPFComboBoxPDDestination.AddChild($newItem)
        }
        # Getting Destination networks
        $script:listNetworkDestination = Get-NTNXNetwork -Servers $WPFtxtBoxClusterDestinationFQDN.Text
        # Update GO and gridView Button
        $WPFButtonGo.IsEnabled = $WPFVMListDataGrid.IsEnabled = !($OKButtonEnabled.ContainsValue($false))
    } catch {
        $_
        $WPFlblClusterDestinationInfo.Content = $_.FullyQualifiedErrorId
        $WPFlblClusterDestinationInfo.Foreground = "Red"
        $OKButtonEnabled.ConnexionDestination = $false
        $WPFButtonGo.IsEnabled = !($OKButtonEnabled.ContainsValue($false))
    }
})



$WPFVMListDataGrid.add_SelectedCellsChanged({
    # Fill the Source Protection Domain Name
    if ($WPFVMListDataGrid.SelectedItem.protectionDomainName) {
        $WPFComboBoxPDSource.SelectedValue = $WPFVMListDataGrid.SelectedItem.protectionDomainName
    } else {
        $WPFComboBoxPDSource.SelectedValue = "None"
    }
    
    # Get VMNics and create appropriate Controls
    $listVMNics = Get-NTNXVMNIC -vmid $WPFVMListDataGrid.SelectedItem.vmId  -Servers $WPFtxtBoxClusterSourceFQDN.Text

    $WPFSPNicInformations.Children.Clear()
    $cpt=1
    foreach ($nic in $listVMNics) {
        [System.Windows.Controls.StackPanel] $WPFSPNic = new-object System.Windows.Controls.StackPanel
        $WPFSPNic.Orientation = "Horizontal"
        $WPFSPNic.HorizontalAlignment = "Center"
        #Source Nic
        [System.Windows.Controls.GroupBox] $WPFGBNicSource = New-Object System.Windows.Controls.GroupBox
        $WPFGBNicSource.Header = "NIC$cpt Source"
        $WPFGBNicSource.Margin = "5,5,5,5"
        [System.Windows.Controls.ComboBox] $WPFCBNicSource = New-Object System.Windows.Controls.ComboBox
        $WPFCBNicSource.SelectedValuePath="Tag"
        $WPFCBNicSource.IsEnabled = $false
        foreach ($net in $script:listNetworkSources) {
            [System.Windows.Controls.ComboBoxItem]$newItem = new-object System.Windows.Controls.ComboBoxItem
            $newItem.Content = $net.name
            $newItem.Tag = $net.uuid
            $WPFCBNicSource.AddChild($newItem)
        }
        $WPFGBNicSource.AddChild($WPFCBNicSource)
        $WPFSPNic.AddChild($WPFGBNicSource)
        $WPFCBNicSource.SelectedValue = $nic.networkUuid

        #Destination Nic
        [System.Windows.Controls.GroupBox] $WPFGBNicDestination = New-Object System.Windows.Controls.GroupBox
        $WPFGBNicDestination.Header = "NIC$cpt Destination"
        $WPFGBNicDestination.Margin = "5,5,5,5"
        [System.Windows.Controls.ComboBox] $WPFCBNicDestination = New-Object System.Windows.Controls.ComboBox
        $WPFCBNicDestination.SelectedValuePath="Tag"
        foreach ($net in $listNetworkDestination) {
            [System.Windows.Controls.ComboBoxItem]$newItem = new-object System.Windows.Controls.ComboBoxItem
            $newItem.Content = $net.name
            $newItem.Tag = $net.uuid
            $WPFCBNicDestination.AddChild($newItem)
        }
        $WPFGBNicDestination.AddChild($WPFCBNicDestination)
        $WPFSPNic.AddChild($WPFGBNicDestination)

        #Final Add
        $WPFSPNicInformations.AddChild($WPFSPNic)
        $cpt++
    }
    # Update the power on option
    $WPFCheckBoxPowerOn.IsChecked = ($WPFVMListDataGrid.SelectedItem.powerState -eq "on")
})

$WPFButtonGo.add_Click({
    $script:continue = $true
    $window.Close()
})

$WPFButtonQuit.add_Click({
    $script:continue = $false
    $window.Close()
})

# dispaly the window
$window.ShowDialog()

if ($script:continue)
{
    write-host "let's move"
    $vmName = $($WPFVMListDataGrid.SelectedItem.vmName)
    # Reconnect to clusters
    $connectionSource = connect-NutanixCluster -server $WPFtxtBoxClusterSourceFQDN.Text -password $WPFtxtBoxClusterSourcePassword.SecurePassword -username $WPFtxtBoxClusterSourceLogin.Text -ForcedConnection
    $connectionDestination = connect-NutanixCluster -server $WPFtxtBoxClusterDestinationFQDN.Text -password $WPFtxtBoxClusterDestinationPassword.SecurePassword -username $WPFtxtBoxClusterDestinationLogin.Text -ForcedConnection
    # get the vm        
    $VM2PowerOff = Get-NTNXVM -Servers $WPFtxtBoxClusterSourceFQDN.Text | where{$_.uuid -eq $WPFVMListDataGrid.SelectedItem.uuid}
    #step0: poweroff vm
    while ($VM2PowerOff.powerState -eq "on") {
        write-host "Sending shutting down signal to VM $vmName ..."
        Set-NTNXVMPowerState -Vmid $WPFVMListDataGrid.SelectedItem.vmId -Transition ACPI_SHUTDOWN -verbose -Servers $WPFtxtBoxClusterSourceFQDN.Text
        start-sleep 10
        # Reconnect to clusters
        $connectionSource = connect-NutanixCluster -server $WPFtxtBoxClusterSourceFQDN.Text -password $WPFtxtBoxClusterSourcePassword.SecurePassword -username $WPFtxtBoxClusterSourceLogin.Text -ForcedConnection
        $connectionDestination = connect-NutanixCluster -server $WPFtxtBoxClusterDestinationFQDN.Text -password $WPFtxtBoxClusterDestinationPassword.SecurePassword -username $WPFtxtBoxClusterDestinationLogin.Text -ForcedConnection
    
        $VM2PowerOff = Get-NTNXVM -Servers $WPFtxtBoxClusterSourceFQDN.Text | where{$_.uuid -eq $WPFVMListDataGrid.SelectedItem.uuid}
    }

    #Step1: create temp protection domain
    $pd_name = "pd_migration_$(Get-Date -format "yyyy-MM-dd_HHmm")"
    $createPD = Add-NTNXProtectionDomain -Value $pd_name -Annotations "Temp Protection Domain to migrate $vmName" -Servers $WPFtxtBoxClusterSourceFQDN.Text
    Start-Sleep 2
    if ($createPD.active -eq $true) {
        Write-Host "Temp Protection Domain $pd_name created"
    } else {
        Write-Warning "Probleme during creation of temp protection domain $pd_name"
        Read-Host "Press a key to exit..."
        exit
    }

    Write-host "Assign Temp protection domain $pd_name"
    #step2: remove current protection domain
    if ($VM2PowerOff.protectionDomainName) {
        Write-host "Removing current protection domain $($VM2PowerOff.protectionDomainName)"
        $removeOldProtectionDomain = Remove-NTNXProtectionDomainVM -PdName $VM2PowerOff.protectionDomainName -InputList $VM2PowerOff.vmname -Servers $WPFtxtBoxClusterSourceFQDN.Text -ErrorAction Stop
		Start-Sleep 5
	}

    #step3: assign temp protection domain
    Try {
        $addVM = Add-NTNXProtectionDomainVM -PdName $pd_name -Ids $VM2PowerOff.uuid -Servers $WPFtxtBoxClusterSourceFQDN.Text -ErrorAction Stop
		Start-Sleep 5
    } Catch {
        Write-Warning "Error during add of $vmName into temp protection domain $pd_name"
        Read-Host "Press a key to exit..."
        exit
    }

    #step4: Migrate the protection domain
    $RemoteSite = Get-NTNXRemoteSite -servers $WPFtxtBoxClusterSourceFQDN.Text
    $MigrateOperation = Migrate-NTNXProtectionDomain -PdName $pd_name -Servers $WPFtxtBoxClusterSourceFQDN.Text -Arg1 $RemoteSite.Name -ErrorAction Stop

    #step 5: Wait for synchronization
    while ($VM2PowerOff) {
        Write-host "Sync in progress...waiting 10 more seconds"
        start-sleep 10
        # Reconnect to clusters
        $connectionSource = connect-NutanixCluster -server $WPFtxtBoxClusterSourceFQDN.Text -password $WPFtxtBoxClusterSourcePassword.SecurePassword -username $WPFtxtBoxClusterSourceLogin.Text -ForcedConnection
        $connectionDestination = connect-NutanixCluster -server $WPFtxtBoxClusterDestinationFQDN.Text -password $WPFtxtBoxClusterDestinationPassword.SecurePassword -username $WPFtxtBoxClusterDestinationLogin.Text -ForcedConnection
        $VM2PowerOff=Get-NTNXVM -Servers $WPFtxtBoxClusterSourceFQDN.Text | where{$_.uuid -eq $WPFVMListDataGrid.SelectedItem.uuid}
    }

    #step 6 : Remove temp protection domain
    do {
        Start-Sleep 1
        $VM2PowerOn=Get-NTNXVM -Servers $WPFtxtBoxClusterDestinationFQDN.Text | where{$_.uuid -eq $WPFVMListDataGrid.SelectedItem.uuid}
    } while ($VM2PowerOn -eq $null)
    Write-host "Remove temp protection domain"
    $removeVM = Remove-NTNXProtectionDomainVM -PdName $pd_name -InputList $VM2PowerOn.vmName -Servers $WPFtxtBoxClusterDestinationFQDN.Text -ErrorAction Stop

    
    #Step 7 : remove temp snapshot
    Start-Sleep 10
    Write-host "Remove temporaries snapshot on destination cluster..."
    foreach ($snapid in $(Get-NTNXProtectionDomainSnapshot -PdName $pd_name -Servers $WPFtxtBoxClusterDestinationFQDN.Text  | where {$_.protectionDomainName -eq $pd_name}).snapshotId) {
        $removeSnap = Remove-NTNXProtectionDomainSnapshot -ProtectionDomainName $pd_name -SnapshotId $snapid -Servers $WPFtxtBoxClusterDestinationFQDN.Text 
        $result = Get-NTNXTask -Taskid $removeSnap.taskUuid -Servers $WPFtxtBoxClusterDestinationFQDN.Text  
    }
    Write-host "Remove temporaries snapshot on source cluster..."
    foreach ($snapid in $(Get-NTNXProtectionDomainSnapshot -PdName $pd_name -Servers $WPFtxtBoxClusterSourceFQDN.Text | where {$_.protectionDomainName -eq $pd_name}).snapshotId) {
        $removeSnap = Remove-NTNXProtectionDomainSnapshot -ProtectionDomainName $pd_name -SnapshotId $snapid -Servers $WPFtxtBoxClusterSourceFQDN.Text
        $result = Get-NTNXTask -Taskid $removeSnap.taskUuid -Servers $WPFtxtBoxClusterSourceFQDN.Text 
    }
    Start-Sleep 10

    #Step 8: Delete temporary protection domain on both sides
    Write-host "Delete Temporary Protection Domain $pd_name on source Cluster"
    $deletePDSource = Mark-NTNXProtectionDomainForRemoval -pdName $pd_Name -Servers $WPFtxtBoxClusterSourceFQDN.Text -ErrorAction Stop
    Write-host "Delete Temporary Protection Domain $pd_name on destination Cluster"
    $deletePDDest = Mark-NTNXProtectionDomainForRemoval -pdName $pd_Name -Servers $WPFtxtBoxClusterDestinationFQDN.Text -ErrorAction Stop
            
    #Step 9: Assign the selected protection domain
    if ($WPFComboBoxPDDestination.Selectedvalue -ne "None") {
        Write-Host "Assign to final protection domain $($WPFComboBoxPDDestination.Selectedvalue)"
        $readdVM = Add-NTNXProtectionDomainVM -PdName $WPFComboBoxPDDestination.Selectedvalue -Ids $VM2PowerOn.uuid -Servers $WPFtxtBoxClusterDestinationFQDN.Text -ErrorAction Stop
    }

    #Step 10: Assign nics
    $cpt=1
    $origNicList = Get-NTNXVMNIC -Vmid $VM2PowerOn.uuid -Servers $WPFtxtBoxClusterDestinationFQDN.Text
    foreach ($nicSPChildControl in $WPFSPNicInformations.Children) {
        # Get selected information
        $groupBoxNicDestination = $nicSPChildControl.Children[1] # the [0] is for the source subnets
        $idNet = $groupBoxNicDestination.Content.SelectedValue #id of the neetwork
        $labelNet = $groupBoxNicDestination.Content.SelectedItem.Content #Name of the network
        $mac = $origNicList[$cpt-1].macAddress
        $isConnected = $origNicList[$cpt-1].isConnected
        Write-Host "Remove the orginal nic"     
        $taskRemove = Remove-NTNXVMNIC -Vmid $VM2PowerOn.uuid -Nicid $mac -Servers $WPFtxtBoxClusterDestinationFQDN.Text
        while ($(Get-NTNXTask -Taskid $taskRemove.taskUuid -Servers $WPFtxtBoxClusterDestinationFQDN.Text).percentageComplete -ne 100) {
            Start-Sleep 1
            Write-host "Waiting for the removal..."
        }

        # Build the new nic
        $nic = New-NTNXObject -Name VMNicSpecDTO
        $nic.networkUuid = $idNet
        $nic.macAddress = $mac
        $nic.isConnected = $isConnected
        write-host "Assigning NIC$cpt to Network id $idNet ($labelNet), with mac adress $mac and Connected: $isConnected"
        # Adding the Nic
        $taskAdd = Add-NTNXVMNic -Vmid $VM2PowerOn.uuid -SpecList $nic -Servers $WPFtxtBoxClusterDestinationFQDN.Text
        while ($(Get-NTNXTask -Taskid $taskAdd.taskUuid -Servers $WPFtxtBoxClusterDestinationFQDN.Text).percentageComplete -ne 100) {
            Start-Sleep 1
            Write-host "Waiting for the adding..."
        }      
        $cpt++
    }


    #Step 11: power on (or not) the migrated vm
    if ($WPFCheckBoxPowerOn.IsChecked) {
        write-host "Power On $vmname"
        Set-NTNXVMPowerOn -Vmid $VM2PowerOn.vmId -Servers $WPFtxtBoxClusterDestinationFQDN.Text
    }	
    Write-Host "Finished" -ForegroundColor Green			
} 
Read-Host "Press a key to exit..."
