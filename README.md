### Give me 2 Windows VMs quick!

If you want to get going really quickly, use [Azure Cloud Shell](https://shell.azure.com):
```
git clone https://github.com/sdolgin/2-win-vms.git
cd ./2-win-vms/
```

Run the following to setup 2 VMs for testing ASR:
```
$sub_id = $(az account show --query id --output tsv)


terraform init
terraform apply -var="subscription_id=$($sub_id)" --auto-approve
```