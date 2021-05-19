
# Create a Function to ensure a strong certificate password is used.
function StrongPassword {
    do {
        $password = Read-Host "-ENTER A SECURE CERTIFICATE PASSWORD-`n`nYour password must meet the following requirements:  
    `n`nAt least one upper case letter [A-Z]`nAt least one lower case letter [a-z]`nAt least one number [0-9]`nAt least one special character (!,@,#,%,^,&,$,_)`nPassword length must be 7 to 25 characters.`n`n`nEnter a certificate password"
    
        if(($password -cmatch '[a-z]') -and ($password -cmatch '[A-Z]') -and ($password -match '\d') -and ($password.length -match '^([7-9]|[1][0-9]|[2][0-5])$') -and ($password -match '!|@|#|%|^|&|$|_')) 
    { 
        Write-Host "`nYour certificate had been saved with your selected password!`n"
        $valid = "True"
        return $password
    } 
    else
    { 
        Write-Host "`nThe password you entered is invalid!`n"
        
    }
    
    } until (
     $valid -eq "True"
    )
    
}