#Concatenation
function Join-Videos{
    param(
        [Parameter(Mandatory=$True,Position=1)] [String] $BaseName, # Files starting with this string will be sorted alphabetically, then concatenated.
        [Parameter(Mandatory=$False,Position=2)] [switch] $Reenecode = $false, # If True, audio and video will be encoded to h.264 and AAC-LC. Othwerise, bitstreams will be copied without re-encoding.
        [Parameter(Mandatory=$False,Position=3)] [switch] $DeleteOriginals = $false # If True, all files match -BaseName will be deleted upon sucessful concatenation. Otherwise, originals will be left as-is.
    )
    
    $OutputName = "$BaseName.mp4"
    $FilesToConcat = Get-ChildItem -Filter "$BaseName*" | Sort-Object -Property "Name"
    $ffmpeg_success = $false

    if($FilesToConcat.Length -eq 0){
        Write-Error 'No files found to concatenate' -ErrorAction Stop
    }

    # Create a temporary Concat File listing - in order - the files to concatenate
    $ConcatFile = New-TemporaryFile
    "#VideosToConcatenate" | Out-File -FilePath $ConcatFile -Encoding ascii
    foreach($File in $FilesToConcat){
        ("file '" + $File.FullName + "'") | Out-File -FilePath $ConcatFile -Encoding ascii -Append
    }

    if ($Renecode){
        ffmpeg -f concat -safe 0 -i $ConcatFile.FullName -vcodec libx264 -crf 19 -pix_fmt yuv420p -preset:v slow -profile:v high -acodec libfdk_aac -b:a 128k -ar 48000 -movflags faststart -y $OutputName
        $ffmpeg_success = $?
    }
    else{
        ffmpeg -f concat -safe 0 -i $ConcatFile.FullName -codec copy -movflags faststart -y $OutputName
        $ffmpeg_success = $?
    }
    Remove-Item $ConcatFile

    if(!$ffmpeg_success) { #Exit if FFMPEG Failed
        
        Write-Error 'Video concatenation failed' -ErrorAction Stop
    }
    elseif ($DeleteOriginals){  #Clean-Up if FFMPEG Succeeded
        foreach($File in $FilesToConcat){
            Remove-Item $File
        }
    }   
}

#Remux MP4
function Remux-Video{
    param(
        [Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)] $Name # The name of the file to Remux
    )
    
    process{
        $ffmpeg_success = $false
        $tempFile = Join-Path ($env:TEMP) ((Get-Random).toString() + ".mp4")
    
        ffmpeg -i $Name -codec copy -movflags faststart -y $tempFile
        $ffmpeg_success = $?

        if(!$ffmpeg_success) { #Exit if FFMPEG Failed
            Remove-Item $tempFile
            Write-Error 'Video remuxing failed' -ErrorAction Stop
        }
        else{  #Clean-Up if FFMPEG Succeeded
            Remove-Item $Name
            Move-Item -Path $tempFile -Destination $Name
        }
    }
}
