module platform.dialog;

version (Windows)
{

    import std.c.windows.windows;
    import win32.shlobj;

    import std.c.string;
    import std.string;
    import win32.objidl;
    import std.conv;

    string showSelectFolderDialogBasic(string startDir)
    {

        string result = null;

        BROWSEINFO bi = BROWSEINFO( null, null, null, null, BIF_USENEWUI | BIF_RETURNONLYFSDIRS);
        bi.lpszTitle = "Pick a Directory";
        LPITEMIDLIST pidl = SHBrowseForFolder ( &bi );

        if ( pidl !is null )
        {
            // get the name of the folder
            wchar[MAX_PATH] path;
            if ( SHGetPathFromIDList ( pidl, path.ptr ) )
            {
                result = path[0..wcslen(path.ptr)].to!string;
            }

            // free memory used
            IMalloc imalloc = null;
            if ( SUCCEEDED( SHGetMalloc ( &imalloc )) )
            {
                imalloc.Free ( pidl );
                imalloc.Release ( );
            }
        }
        return result;
    }

    unittest
    {
        import std.stdio;
        writeln(showSelectFolderDialogBasic("c:\\"));
    }


    //HRESULT BasicFileOpen()
/+
    string showSelectFolderDialogBasic(string startDir)
    {
        import c.windows.shobjidl;

        // CoCreate the File Open Dialog object.
        IFileDialog *pfd = NULL;
        HRESULT hr = CoCreateI!nstance(CLSID_FileOpenDialog,
                                      NULL,
                                      CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&pfd));
        if (SUCCEEDED(hr))
        {
            // Create an event handling object, and hook it up to the dialog.
            IFileDialogEvents *pfde = NULL;
            hr = CDialogEventHandler_CreateInstance(IID_PPV_ARGS(&pfde));
            if (SUCCEEDED(hr))
            {
                // Hook up the event handler.
                DWORD dwCookie;
                hr = pfd.Advise(pfde, &dwCookie);
                if (SUCCEEDED(hr))
                {
                    // Set the options on the dialog.
                    DWORD dwFlags;

                    // Before setting, always get the options first in order
                    // not to override existing options.
                    hr = pfd.GetOptions(&dwFlags);
                    if (SUCCEEDED(hr))
                    {
                        // In this case, get shell items only for file system items.
                        hr = pfd.SetOptions(dwFlags | FOS_FORCEFILESYSTEM);
                        if (SUCCEEDED(hr))
                        {
                            // Set the file types to display only.
                            // Notice that this is a 1-based array.
                            hr = pfd.SetFileTypes(ARRAYSIZE(c_rgSaveTypes), c_rgSaveTypes);
                            if (SUCCEEDED(hr))
                            {
                                // Set the selected file type index to Word Docs for this example.
                                hr = pfd.SetFileTypeIndex(INDEX_WORDDOC);
                                if (SUCCEEDED(hr))
                                {
                                    // Set the default extension to be ".doc" file.
                                    hr = pfd.SetDefaultExtension("doc;docx"w);
                                    if (SUCCEEDED(hr))
                                    {
                                        // Show the dialog
                                        hr = pfd.Show(NULL);
                                        if (SUCCEEDED(hr))
                                        {
                                            // Obtain the result once the user clicks
                                            // the 'Open' button.
                                            // The result is an IShellItem object.
                                            IShellItem *psiResult;
                                            hr = pfd.GetResult(&psiResult);
                                            if (SUCCEEDED(hr))
                                            {
                                                // We are just going to print out the
                                                // name of the file for sample sake.
                                                wchar* pszFilePath = null;
                                                hr = psiResult.GetDisplayName(SIGDN_FILESYSPATH,
                                                                               &pszFilePath);
                                                if (SUCCEEDED(hr))
                                                {
                                                    TaskDialog(null,
                                                               null,
                                                               "CommonFileDialogApp"w,
                                                               pszFilePath,
                                                               null,
                                                               TDCBF_OK_BUTTON,
                                                               TD_INFORMATION_ICON,
                                                               null);
                                                    CoTaskMemFree(pszFilePath);
                                                }
                                                psiResult.Release();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Unhook the event handler.
                    pfd.Unadvise(dwCookie);
                }
                pfde.Release();
            }
            pfd.Release();
        }
        return hr;
    }
+/
}
