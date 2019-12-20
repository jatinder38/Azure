#  will now create the PowerShell that does the actual work. We'll start by declaring some variables


param( 
    [parameter(Mandatory=$false)] 
    [bool]$scaleUp = $false, 
    
    [parameter(Mandatory=$false)] 
    [string]$ScaleUpSize = "Standard_D2_V2",
    [parameter(Mandatory=$false)] 
    [string]$ScaleDownSize = "Standard_B1ms"    
)  



<# The first one is going to determine if we scale up or down. 
The second and third variables indicate to which tier we should scale up or down. For instance to "Standard_D2_V2". #>

<# Next, we add PowerShell script to log into Azure. 
We do that using the AzureRunAsConnection that Azure Automation has created for us automatically #>


try 
{ 
    "Logging in to Azure..." 
    $runAsConnectionProfile = Get-AutomationConnection `
    -Name "AzureRunAsConnection"
    Add-AzureRmAccount -ServicePrincipal `
    -TenantId $runAsConnectionProfile.TenantId `
    -ApplicationId $runAsConnectionProfile.ApplicationId `
    -CertificateThumbprint ` $runAsConnectionProfile.CertificateThumbprint | Out-Null
    Write-Output "Authenticated with Automation Run As Account."
}



<# Once we are successfully logged in, we can set variables that determine the tier that we scale to. When $ScaleUp is true, 
we use the $ScaleUpSize parameter. And when it is false, we use the $ScaleDownSize parameter #>


if($scaleUp){ 
    $ScaleSize= $ScaleUpSize 
} 
else{ 
    $ScaleSize= $ScaleDownSize 
} 


<# Now, for the meat of the script. In the script below, the following happens a. First, we get all of the resource groups and loop through
them b. In each resource group, we find all of the VMs and loop through them c. Next, we get the current size of the VM (so the pricing tier) 
and compare that against the size that we want to scale to. If the VM is already the same size, we don't scale it d. Next, we check if the VM 
is running and stop it if it is running e. Finally, we update the VM with the new size #>


Function Start-VMAutoScaling{ 
    # a. First, we get all of the resource groups and loop through them
    $RGs = Get-AzureRMResourceGroup 
    foreach($RG in $RGs){ 
        $RGN = $RG.ResourceGroupName 
        $VMs = Get-AzureRmVM -ResourceGroupName $RGN 
            foreach ($VM in $VMs){ 
                # b. In each resource group, we find all of the VMs and loop through them
                $VMName = $VM.Name      
                $VMDetail = Get-AzureRmVM -ResourceGroupName $RGN -Name $VMName 
                $VMSize = $VMDetail.HardwareProfile.VmSize 
                if(($VMSize -ne $ScaleSize) -and ($ScaleSize)){
                    # c. Next, we get the current size of the VM (so the pricing tier) and compare that against the size
                    #that we want to scale to. 
                    Write-Output "Resource Group: $RGN", ("VM Name: " + $VMName), "Current VM Size: $VMSize", "$scaleTagSwitch : $ScaleSize"  
                    $VMStatus = Get-AzureRmVM -ResourceGroupName $RGN -Name $VMName -Status 
                    
                    # d. Next, we check if the VM is running and stop it if it is running
                    if($VMStatus.Statuses[1].DisplayStatus -eq "VM running"){ 
                        Write-Output "Stopping VM '$VMName'" 
                        Stop-AzureRmVM -ResourceGroupName $RGN -Name $VMName -Force | Out-Null 
                    }  

                    # e. Finally, we update the VM with the new size
                    $VM.HardwareProfile.VmSize = $ScaleSize 
                    Update-AzureRmVM -VM $VM -ResourceGroupName $RGN  
                    Write-Output "Resized VM '$VMName'" `n  
                }                
                else{ 
                    Write-Output "VM '$VMName' is exempted from scaling (Currrent VM size matches scaling size)" 
                } 
            } 
    } 
} 



#Finally, we call the Start-VMAutoscaling function
############################ Start autoscaling function #################### 
 
Start-VMAutoScaling 
Write-Output "VM Scaling Completed" 
© 2019 GitHub, Inc.
Terms
Privacy
Security
Status
Help
Contact GitHub
Pricing
API
Training
Blog
About
