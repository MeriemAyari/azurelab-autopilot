param(
  [string]$TenantId       = "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx",
  [string]$SubscriptionId = "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx",
  [string]$TerraformDir   = "C:\Projects\azurelab-autopilot\terraform",
  [switch]$InstallMissingAzModules = $true
)

function Info($m){ Write-Host "[INFO] $m" -ForegroundColor DarkGray }
function Ok($m){ Write-Host "[OK]   $m" -ForegroundColor Green }
function Skip($m){ Write-Host "[SKIP] $m" -ForegroundColor Yellow }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ Write-Host "[FAIL] $m" -ForegroundColor Red }

function Ensure-PSGalleryTrusted {
  try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($repo.InstallationPolicy -ne "Trusted") {
      Info "Setting PSGallery InstallationPolicy = Trusted"
      Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    } else { Skip "PSGallery already Trusted" }
  } catch {
    Warn "Cannot query PSGallery repository. If Install-Module fails, check proxy/firewall."
  }
}
function Read-PasswordValidated {
  param(
    [string]$Label = "Admin password (hidden)",
    [int]$MinLength = 12
  )

  while ($true) {
    $p1 = Read-Host " > $Label" -AsSecureString
    $p2 = Read-Host " > Confirm password (hidden)" -AsSecureString

    $s1 = SecureToPlain $p1
    $s2 = SecureToPlain $p2

    if ($s1 -ne $s2) {
      Warn "Passwords do not match. Retry."
      continue
    }

    if ($s1.Length -lt $MinLength) {
      Warn "Password too short. Minimum length is $MinLength."
      continue
    }

    if ($s1 -notmatch "[A-Z]") { Warn "Password must contain at least one uppercase letter."; continue }
    if ($s1 -notmatch "[a-z]") { Warn "Password must contain at least one lowercase letter."; continue }
    if ($s1 -notmatch "\d")    { Warn "Password must contain at least one number."; continue }
    if ($s1 -notmatch "[^a-zA-Z0-9]") { Warn "Password must contain at least one special character."; continue }

    Ok "Password validation passed."
    return $s1
  }
}

function Ensure-AzModule([string]$ModuleName) {
  if (Get-Module -ListAvailable -Name $ModuleName) { Skip "$ModuleName already installed" }
  else {
    if (-not $InstallMissingAzModules) { throw "Missing module: $ModuleName" }
    Info "Installing $ModuleName (CurrentUser)..."
    Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Ok "$ModuleName installed"
  }
  if (Get-Module -Name $ModuleName) { Skip "$ModuleName already imported" }
  else { Import-Module $ModuleName -ErrorAction Stop; Ok "$ModuleName imported" }
}

function Read-Required([string]$Label) {
  while ($true) {
    $v = Read-Host " > $Label"
    if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
    Warn "Value required. Retry."
  }
}

function Read-Int([string]$Label) {
  while ($true) {
    $v = Read-Host " > $Label"
    if ($v -match '^\d+$') { return [int]$v }
    Warn "Enter a number."
  }
}

function SecureToPlain([Security.SecureString]$s) {
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Select-FromDropDown {
  param(
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string]$Label,
    [Parameter(Mandatory=$true)][string[]]$Items
  )

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $form = New-Object System.Windows.Forms.Form
  $form.Text = $Title
  $form.Size = New-Object System.Drawing.Size(860,180)
  $form.StartPosition = "CenterScreen"
  $form.Topmost = $true

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = $Label
  $lbl.AutoSize = $true
  $lbl.Location = New-Object System.Drawing.Point(10,15)
  $form.Controls.Add($lbl)

  $combo = New-Object System.Windows.Forms.ComboBox
  $combo.Location = New-Object System.Drawing.Point(10,40)
  $combo.Size = New-Object System.Drawing.Size(820,25)
  $combo.DropDownStyle = "DropDown"
  $combo.AutoCompleteMode = "SuggestAppend"
  $combo.AutoCompleteSource = "ListItems"
  $combo.Items.AddRange($Items)
  if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
  $form.Controls.Add($combo)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = "OK"
  $ok.Location = New-Object System.Drawing.Point(660,80)
  $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $form.AcceptButton = $ok
  $form.Controls.Add($ok)

  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = "Cancel"
  $cancel.Location = New-Object System.Drawing.Point(745,80)
  $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $form.CancelButton = $cancel
  $form.Controls.Add($cancel)

  $result = $form.ShowDialog()
  if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $combo.Text }
  return $null
}

# Modules Az
if (Get-Module -ListAvailable -Name AzureRM -ErrorAction SilentlyContinue) {
  Warn "AzureRM detected. Workaround mode enabled (sizes via Get-AzComputeResourceSku)."
}

Ensure-PSGalleryTrusted
try {
  Ensure-AzModule "Az.Accounts"
  Ensure-AzModule "Az.Resources"
  Ensure-AzModule "Az.Compute"
} catch {
  Fail "Az prerequisites not ready: $($_.Exception.Message)"
  exit 1
}

# Azure login
try {
  Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId | Out-Null
  Set-AzContext -TenantId $TenantId -SubscriptionId $SubscriptionId | Out-Null
  $ctx = Get-AzContext

  Write-Host ""
  Ok "CONNECTED TO AZURE"
  Info ("Account      : {0}" -f $ctx.Account)
  Info ("Tenant       : {0}" -f $ctx.Tenant)
  Info ("Subscription : {0}" -f $ctx.Subscription)
  Info ("Environment  : {0}" -f $ctx.Environment)
} catch {
  Fail "Azure login failed: $($_.Exception.Message)"
  exit 1
}

# Inputs
Write-Host ""
Write-Host "AUTOPILOT INPUTS (will generate terraform.auto.tfvars)" -ForegroundColor Cyan
Info ("Terraform folder: {0}" -f $TerraformDir)

$rgName = Read-Required "Resource Group name (Terraform will create it)"
$vmName = Read-Required "VM name (ex: vm-test01)"
$privIp = Read-Required "Private IP (static) (ex: 10.0.1.10)"

# Location dropdown
$locs = Get-AzLocation | Sort-Object Location
$locItems = $locs | ForEach-Object { "$($_.Location) - $($_.DisplayName)" }
$locChoice = Select-FromDropDown -Title "Azure Location" -Label "Select a location (type to search, e.g. westeurope):" -Items $locItems
if (-not $locChoice) { Fail "No location selected."; exit 1 }
$location = ($locChoice -split " - ")[0].Trim()
Info ("Selected location: {0}" -f $location)

# Pre-check RG (READ-ONLY)
$existingRg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if ($existingRg) {
  Warn "Resource Group '$rgName' already exists in Azure (location: $($existingRg.Location))."
  Warn "Terraform will fail to create it unless you import it. Recommendation: use a new RG name."
  $ans = (Read-Host " > Continue anyway? (y/n)").Trim().ToLower()
  if ($ans -ne "y") { throw "Aborted by user. Choose another RG name." }
}

# Family dropdown
$families = @("A-family (Standard_A*)","B-family (Standard_B*)","D-family (Standard_D*)","DC-family (Standard_DC*)")
$famChoice = Select-FromDropDown -Title "VM Family" -Label "Select VM family:" -Items $families
if (-not $famChoice) { Fail "No family selected."; exit 1 }

$prefix = if ($famChoice -like "A-family*") { "Standard_A" }
elseif ($famChoice -like "B-family*") { "Standard_B" }
elseif ($famChoice -like "D-family*") { "Standard_D" }
else { "Standard_DC" }

# Sizes via ComputeResourceSku (workaround)
Info "Loading VM sizes via Get-AzComputeResourceSku (workaround)"
$sizesAll = Get-AzComputeResourceSku -Location $location |
  Where-Object { $_.ResourceType -eq "virtualMachines" } |
  Sort-Object Name
$sizesFam = $sizesAll | Where-Object { $_.Name -like "$prefix*" }
if (-not $sizesFam) { Warn "No sizes matched family; showing all VM sizes."; $sizesFam = $sizesAll }

$sizeItems = $sizesFam | Select-Object -First 200 | ForEach-Object {
  $v = ($_.Capabilities | Where-Object Name -eq "vCPUs").Value
  $m = ($_.Capabilities | Where-Object Name -eq "MemoryGB").Value
  "$($_.Name) | vCPU:$v | RAM_GB:$m"
}

$sizeChoice = Select-FromDropDown -Title "VM Size" -Label "Select VM size (type to search, e.g. B2ms):" -Items $sizeItems
if (-not $sizeChoice) { Fail "No size selected."; exit 1 }
$vmSize = ($sizeChoice -split "\|")[0].Trim()
Info ("Selected VM size: {0}" -f $vmSize)

# Disks + public IP
$diskTypes = @("Standard_LRS","StandardSSD_LRS","Premium_LRS")
$osDiskType = Select-FromDropDown -Title "OS Disk Type" -Label "Select OS disk type:" -Items $diskTypes
$osDiskSize = Read-Int "OS disk size (GB) (ex: 128)"
$dataDiskSize = Read-Int "Data disk size (GB) (0 = none)"
$dataDiskType = Select-FromDropDown -Title "DATA Disk Type" -Label "Select DATA disk type:" -Items $diskTypes
$enablePip = ((Read-Host "Enable Public IP? (y/n)").Trim().ToLower() -eq "y")

# Windows image
$imagePublisher = "MicrosoftWindowsServer"
$imageOffer     = "WindowsServer"
$imageSku       = "2022-datacenter-g2"
$imageVersion   = "latest"

$adminUser = Read-Required "Admin username"
#$adminPass = SecureToPlain (Read-Host "Admin password (hidden)" -AsSecureString)
$adminPass = Read-PasswordValidated -Label "Admin password (hidden)" -MinLength 12

$dnsServers = @("$privIp","168.63.129.16")

# Generate terraform.auto.tfvars
if (-not (Test-Path $TerraformDir)) { Fail "TerraformDir not found: $TerraformDir"; exit 1 }

$tfvars = Join-Path $TerraformDir "terraform.auto.tfvars"

@"
location            = "$location"
resource_group_name = "$rgName"
environment         = "lab"
admin_username      = "$adminUser"
admin_password      = "$adminPass"

vnet_address_space = ["10.0.0.0/16"]
subnet_configs = {
  snet-test = {
    address_prefix = "10.0.1.0/24"
  }
}

dns_servers = ["$($dnsServers[0])", "$($dnsServers[1])"]

test_vm_config = {
  name             = "$vmName"
  size             = "$vmSize"
  private_ip       = "$privIp"
  os_disk_size     = $osDiskSize
  os_disk_type     = "$osDiskType"
  data_disk_size   = $dataDiskSize
  data_disk_type   = "$dataDiskType"
  enable_public_ip = $($enablePip.ToString().ToLower())
  image = {
    publisher = "$imagePublisher"
    offer     = "$imageOffer"
    sku       = "$imageSku"
    version   = "$imageVersion"
  }
}
"@ | Set-Content -Path $tfvars -Encoding UTF8

Write-Host ""
Ok ("Generated tfvars: {0}" -f $tfvars)
Warn "Do NOT commit terraform.auto.tfvars or tfstate."

# Terraform actions
Write-Host ""
Write-Host "Terraform action: 0=none, 1=init+plan, 2=fmt+init+validate+plan+apply" -ForegroundColor Cyan
$action = (Read-Host "Enter choice").Trim()

if ($action -eq "1" -or $action -eq "2") {
  if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Fail "Terraform CLI not found in PATH."
    exit 1
  }

  Push-Location $TerraformDir

  terraform fmt -recursive
  terraform init
  terraform validate
  terraform plan

  if ($action -eq "2") {
    $confirm = (Read-Host " > Type APPLY to continue").Trim()
    if ($confirm -ne "APPLY") { throw "Apply cancelled." }
    terraform apply
  }

  Pop-Location
} else {
  Info "No Terraform command executed (choice 0)."
}