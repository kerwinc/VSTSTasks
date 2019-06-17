# $array = @()
# $object = New-Object -TypeName PSObject
# $object | Add-Member -Name 'name' -MemberType Noteproperty -Value 'refs/heads/release/M4'
# $object | Add-Member -Name 'newObjectId' -MemberType Noteproperty -Value '75fcbbbd097b39c5683e6b314d1f87fbf7d02dd4'
# $object | Add-Member -Name 'oldObjectId' -MemberType Noteproperty -Value '0000000000000000000000000000000000000000'
# $array += $object
# $body = ConvertTo-Json $array

# $body

$body = ConvertTo-Json @(@{name="refs/heads/release/M4";newObjectId="75fcbbbd097b39c5683e6b314d1f87fbf7d02dd4";oldObjectId="0000000000000000000000000000000000000000"})
$body