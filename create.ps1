$config = ConvertFrom-Json $configuration;
$p = $person | ConvertFrom-Json

$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$success = $false


function New-AccessToken() {
    [cmdletbinding()]
    Param (
        [object]$config
    )
    Process
    {
        #Get OAuth Token
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $Token = [System.Convert]::ToBase64String( [System.Text.Encoding]::ASCII.GetBytes("$($config.apiKey):$($config.apiSecret)") );
        $headers = @{ Authorization = "Basic " + $Token };
        $tokenResponse = Invoke-RestMethod -uri "$($config.baseurl)/oauth/access_token" -Method 'POST' -Headers $headers -Body (@{grant_type= "client_credentials";})
        $headers = @{
            "Authorization"= "Bearer $($tokenResponse.access_token)"
            "Accept"= "application/json"
        }
        return $headers;
    }
}

function Get-ErrorMessage
{
    [cmdletbinding()]
    param (
        [object]$Response
    )
    try {
        $reader = New-Object System.IO.StreamReader($Response.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        Write-Error "StatusCode: $($Response.Exception.Response.StatusCode.value__)`nStatusDescription: $($Response.Exception.Response.StatusDescription)`nMessage: $($reader.ReadToEnd())"
    } catch
    {
        Write-Information $response
    }
}
$headers = New-AccessToken -Config $config;
try
        {
            $uri = "$($config.baseurl)/ws/v1/student"
            $body = @{
                "students"= @{
                    "student" = @{
                        "client_uid" = "HelloID"
                        "action" = "UPDATE"
                        "id" = "INSERT_POWERSCHOOLID"
                        "contact_info" = @{
                            "email" = "INSERT_EMAIL"
                        }
                    }
                }
            }

            if (-Not($dryRun -eq $true))
            {

                $result = Invoke-RestMethod -Method POST -Headers $headers -Uri $uri -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
                #Handles return status errors if api call is successful, but is not Status:SUCCESS
                if($result.results.result.status -ne "SUCCESS")
                {
                                        
                    $auditLogs.Add([PSCustomObject]@{
                    Action = "GrantPermission"
                    Message = "Script processed, but Powerschool write-wack for $($p.Displayname) was not successful. Status: $($result.results.result.status) Error: $($result.results.result.error_message.error_description)"
                    IsError = $true;
                    });

                    Write-Information ("Script processed, but Powerschool write-back was not Successful. Status : {0} Error: {1}" -f $result.results.result.status, $result.results.result.error_message.error_description)

                } else {

                    $auditLogs.Add([PSCustomObject]@{
                    Action = "GrantPermission"
                    Message = "Powerschool Write-Back for $($p.Displayname) was successful"
                    IsError = $false;
                    });
                    
                    Write-Information ("Powerschool write-back for {0} was successful" -f $p.Displayname)                    
                    $success = $true
                }
            
            }

        }
        catch
        {
            Get-ErrorMessage -response $_;
            throw $_
        }

$result = [PSCustomObject]@{
    Success= $success;
    AccountReference= $p.externalID
    AuditLogs = $auditLogs

    ExportData = [PSCustomObject]@{
        Email = "INSERT_EMAIL"
    }
};

Write-Output $result | ConvertTo-Json -Depth 10
#endregion build up result
