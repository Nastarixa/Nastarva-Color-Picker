#Requires AutoHotkey v2.0
inputSize := (A_PtrSize = 8) ? 24 : 16
input := Buffer(inputSize, 0)
NumPut("UInt", 1, input, 0)
token := 0
status := DllCall("gdiplus\\GdiplusStartup", "Ptr*", token, "Ptr", input.Ptr, "Ptr", 0, "UInt")
out := A_ScriptDir "\\_gdip_result.txt"
if FileExist(out)
    FileDelete(out)
FileAppend("status=" status " token=" token " ptrsize=" A_PtrSize, out, "UTF-8")
if (token)
    DllCall("gdiplus\\GdiplusShutdown", "Ptr", token)
