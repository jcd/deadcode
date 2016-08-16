module platform.dialog;


version (Windows)
{
    import core.sys.windows.windows;
    import win32.shlobj;

    import core.stdc.wctype;
    import std.string;
    import win32.objidl;
    import std.conv;

	GUID parseGUID(string spec)
	{
		GUID g;

		static int nybbleFromHex(char b)
		{
			ubyte x = cast(ubyte) b;

			if (x >= cast(ubyte)'a' && x <= cast(ubyte)'f')
			{
				return 0xa + (x - cast(ubyte)'a');
			}
			if (x >= cast(ubyte)'A' && x <= cast(ubyte)'F')
			{
				return 0xa + (x - cast(ubyte)'A');
			}
			else if (x >= cast(ubyte)'0' && x <= cast(ubyte)'9')
			{
				return x - cast(ubyte)'0';
			}
			else
			{
				assert(0);
			}
		}

        for( int i = 0;  i < 8;  ++i )
        {
			g.Data1 = (g.Data1 << 4) | nybbleFromHex( spec[i] );
        }
        assert( spec[8] == '-' );
        for( int i = 9;  i < 13;  ++i )
        {
			g.Data2 = cast(ushort)((g.Data2 << 4) | nybbleFromHex( spec[i] ));
        }
        assert( spec[13] == '-' );
        for( int i = 14; i < 18;  ++i )
        {
			g.Data3 = cast(ushort)((g.Data3 << 4) | nybbleFromHex( spec[i] ));
        }
        assert( spec[18] == '-' );
        for( int i = 19; i < 23;  i += 2 )
        {
			g.Data4[(i - 19)/2] = cast(ubyte) ((nybbleFromHex( spec[i] ) << 4) | nybbleFromHex( spec[i + 1] ));
        }
        assert( spec[23] == '-' );
        for( int i = 24; i < 36;  i += 2 )
        {
			g.Data4[2 + (i - 24)/2] = cast(ubyte) ((nybbleFromHex( spec[i] ) << 4) | nybbleFromHex( spec[i + 1] ));
        }
		return g;
	}

	mixin template DEFINE_IID(T, string _CLDID)
	{
		mixin("enum CLSID_" ~ T.stringof ~ " = parseGUID(\"" ~ _CLDID ~ "\");"); 
	}

	mixin template DEFINE_GUID(T, string _CLDID)
	{
		mixin("enum CLSID_" ~ T.stringof ~ " = parseGUID(\"" ~ _CLDID ~ "\");"); 
	}

    enum MessageBoxStyle
    {
        none,
        error = MB_ICONERROR,
        yesNo = MB_YESNO,
        modal = MB_TASKMODAL,
    }

    int messageBox(string title, string message, MessageBoxStyle t)
    {
        import std.string;
        return MessageBoxA(null, message.toStringz(), title.toStringz(), t);
    }

    string showSelectFolderDialogBasicx(string startDir)
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
        //import std.stdio;
        //writeln(showSelectFolderDialogBasic("c:\\"));
    }

	import core.sys.windows.oleidl;

	enum {
		SHCIDS_ALLFIELDS      = 0x80000000,
		SHCIDS_CANONICALONLY  = 0x10000000,
		SHCIDS_BITMASK        = 0xFFFF0000,
		SHCIDS_COLUMNMASK     = 0x0000FFFF,
		SFGAO_CANCOPY         = DROPEFFECT.DROPEFFECT_COPY,
		SFGAO_CANMOVE         = DROPEFFECT.DROPEFFECT_MOVE,
		SFGAO_CANLINK         = DROPEFFECT.DROPEFFECT_LINK,
		SFGAO_STORAGE         = 0x00000008,
		SFGAO_CANRENAME       = 0x00000010,
		SFGAO_CANDELETE       = 0x00000020,
		SFGAO_HASPROPSHEET    = 0x00000040,
		SFGAO_DROPTARGET      = 0x00000100,
		SFGAO_CAPABILITYMASK  = 0x00000177,
		SFGAO_SYSTEM          = 0x00001000,
		SFGAO_ENCRYPTED       = 0x00002000,
		SFGAO_ISSLOW          = 0x00004000,
		SFGAO_GHOSTED         = 0x00008000,
		SFGAO_LINK            = 0x00010000,
		SFGAO_SHARE           = 0x00020000,
		SFGAO_READONLY        = 0x00040000,
		SFGAO_HIDDEN          = 0x00080000,
		SFGAO_DISPLAYATTRMASK = 0x000FC000,
		SFGAO_FILESYSANCESTOR = 0x10000000,
		SFGAO_FOLDER          = 0x20000000,
		SFGAO_FILESYSTEM      = 0x40000000,
		SFGAO_HASSUBFOLDER    = 0x80000000,
		SFGAO_CONTENTSMASK    = 0x80000000,
		SFGAO_VALIDATE        = 0x01000000,
		SFGAO_REMOVABLE       = 0x02000000,
		SFGAO_COMPRESSED      = 0x04000000,
		SFGAO_BROWSABLE       = 0x08000000,
		SFGAO_NONENUMERATED   = 0x00100000,
		SFGAO_NEWCONTENT      = 0x00200000,
		SFGAO_CANMONIKER      = 0x00400000,
		SFGAO_HASSTORAGE      = 0x00400000,
		SFGAO_STREAM          = 0x00400000,
		SFGAO_STORAGEANCESTOR = 0x00800000,
		SFGAO_STORAGECAPMASK  = 0x70C50008,
		SFGAO_PKEYSFGAOMASK   = 0x81044000,
	}
	alias ULONG SFGAOF;

	enum {
		SIGDN_NORMALDISPLAY               = 0,
		SIGDN_PARENTRELATIVEPARSING       = cast(int)0x80018001,
		SIGDN_DESKTOPABSOLUTEPARSING      = cast(int)0x80028000,
		SIGDN_PARENTRELATIVEEDITING       = cast(int)0x80031001,
		SIGDN_DESKTOPABSOLUTEEDITING      = cast(int)0x8004c000,
		SIGDN_FILESYSPATH                 = cast(int)0x80058000,
		SIGDN_URL                         = cast(int)0x80068000,
		SIGDN_PARENTRELATIVEFORADDRESSBAR = cast(int)0x8007c001,
		SIGDN_PARENTRELATIVE              = cast(int)0x80080001
	}
	alias int SIGDN;

	enum {
		SICHINT_DISPLAY                       = 0,
		SICHINT_ALLFIELDS                     = cast(int)0x80000000,
		SICHINT_CANONICAL                     = 0x10000000,
		SICHINT_TEST_FILESYSPATH_IF_NOT_EQUAL = 0x20000000
	}
	alias DWORD SICHINTF;

	//extern extern(C) const IID IID_IShellItem;
	interface IShellItem : IUnknown {
		public extern(Windows):
		HRESULT BindToHandler(IBindCtx pbc, REFGUID bhid, REFIID riid, void** ppv);
		HRESULT GetParent(IShellItem* ppsi);
		HRESULT GetDisplayName(SIGDN sigdnName, LPWSTR* ppszName);
		HRESULT GetAttributes(SFGAOF sfgaoMask, SFGAOF* psfgaoAttribs);
		HRESULT Compare(IShellItem psi, SICHINTF hint, int* piOrder);
	}
	mixin DEFINE_IID!(IShellItem, "43826d1e-e718-42ee-bc55-a1e261c37bfe");

	enum {
		SHCONTF_CHECKING_FOR_CHILDREN = 0x10,
		SHCONTF_FOLDERS               = 0x20,
		SHCONTF_NONFOLDERS            = 0x40,
		SHCONTF_INCLUDEHIDDEN         = 0x80,
		SHCONTF_INIT_ON_FIRST_NEXT    = 0x100,
		SHCONTF_NETPRINTERSRCH        = 0x200,
		SHCONTF_SHAREABLE             = 0x400,
		SHCONTF_STORAGE               = 0x800,
		SHCONTF_NAVIGATION_ENUM       = 0x1000,
		SHCONTF_FASTITEMS             = 0x2000,
		SHCONTF_FLATLIST              = 0x4000,
		SHCONTF_ENABLE_ASYNC          = 0x8000,
		SHCONTF_INCLUDESUPERHIDDEN    = 0x10000
	}
	alias DWORD SHCONTF;

	//extern extern(C) const IID IID_IShellItemFilter;
	interface IShellItemFilter : IUnknown {
		public extern(Windows):
		HRESULT IncludeItem(IShellItem psi);
		HRESULT GetEnumFlagsForItem(IShellItem psi, SHCONTF* pgrfFlags);
	}
	mixin DEFINE_IID!(IShellItemFilter, "2659B475-EEB8-48b7-8F07-B378810F48CF");

	interface IModalWindow : IUnknown {
		public extern(Windows):
		HRESULT Show(HWND hwndOwner);
	}
	mixin DEFINE_IID!(IModalWindow, "b4db1657-70d7-485e-8e3e-6fcb5a5c1802");

	export extern(Windows){
		HRESULT IModalWindow_RemoteShow_Proxy(IModalWindow This, HWND hwndOwner);
		void IModalWindow_RemoteShow_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}

	enum {
		FDEOR_DEFAULT = 0,
		FDEOR_ACCEPT  = 1,
		FDEOR_REFUSE  = 2
	}
	alias int FDE_OVERWRITE_RESPONSE;

	enum {
		FDESVR_DEFAULT = 0,
		FDESVR_ACCEPT  = 1,
		FDESVR_REFUSE  = 2
	}
	alias int FDE_SHAREVIOLATION_RESPONSE;

	enum {
		FDAP_BOTTOM = 0,
		FDAP_TOP    = 1
	}
	alias int FDAP;

	//extern extern(C) const IID IID_IFileDialogEvents;
	interface IFileDialogEvents : IUnknown {
		public extern(Windows):
		HRESULT OnFileOk(IFileDialog pfd);
		HRESULT OnFolderChanging(IFileDialog pfd, IShellItem psiFolder);
		HRESULT OnFolderChange(IFileDialog pfd);
		HRESULT OnSelectionChange(IFileDialog pfd);
		HRESULT OnShareViolation(IFileDialog pfd, IShellItem psi, FDE_SHAREVIOLATION_RESPONSE* pResponse);
		HRESULT OnTypeChange(IFileDialog pfd);
		HRESULT OnOverwrite(IFileDialog pfd, IShellItem psi, FDE_OVERWRITE_RESPONSE* pResponse);
	}
	mixin DEFINE_IID!(IFileDialogEvents, "973510db-7d7f-452b-8975-74a85828d354");

	enum {
		FOS_OVERWRITEPROMPT    = 0x2,
		FOS_STRICTFILETYPES    = 0x4,
		FOS_NOCHANGEDIR        = 0x8,
		FOS_PICKFOLDERS        = 0x20,
		FOS_FORCEFILESYSTEM    = 0x40,
		FOS_ALLNONSTORAGEITEMS = 0x80,
		FOS_NOVALIDATE         = 0x100,
		FOS_ALLOWMULTISELECT   = 0x200,
		FOS_PATHMUSTEXIST      = 0x800,
		FOS_FILEMUSTEXIST      = 0x1000,
		FOS_CREATEPROMPT       = 0x2000,
		FOS_SHAREAWARE         = 0x4000,
		FOS_NOREADONLYRETURN   = 0x8000,
		FOS_NOTESTFILECREATE   = 0x10000,
		FOS_HIDEMRUPLACES      = 0x20000,
		FOS_HIDEPINNEDPLACES   = 0x40000,
		FOS_NODEREFERENCELINKS = 0x100000,
		FOS_DONTADDTORECENT    = 0x2000000,
		FOS_FORCESHOWHIDDEN    = 0x10000000,
		FOS_DEFAULTNOMINIMODE  = 0x20000000,
		FOS_FORCEPREVIEWPANEON = 0x40000000
	}
	alias DWORD FILEOPENDIALOGOPTIONS;

	// Hack (jcd)
	alias COMDLG_FILTERSPEC = int;

	//extern extern(C) const IID IID_IFileDialog;
	interface IFileDialog : IModalWindow {
		public extern(Windows):
		HRESULT SetFileTypes( UINT cFileTypes, const(COMDLG_FILTERSPEC)* rgFilterSpec);
		HRESULT SetFileTypeIndex(UINT iFileType);
		HRESULT GetFileTypeIndex(UINT* piFileType);
		HRESULT Advise(IFileDialogEvents pfde, DWORD* pdwCookie);
		HRESULT Unadvise(DWORD dwCookie);
		HRESULT SetOptions(FILEOPENDIALOGOPTIONS fos);
		HRESULT GetOptions(FILEOPENDIALOGOPTIONS* pfos);
		HRESULT SetDefaultFolder(IShellItem psi);
		HRESULT SetFolder(IShellItem psi);
		HRESULT GetFolder(IShellItem* ppsi);
		HRESULT GetCurrentSelection(IShellItem* ppsi);
		HRESULT SetFileName(LPCWSTR pszName);
		HRESULT GetFileName(LPWSTR* pszName);
		HRESULT SetTitle(LPCWSTR pszTitle);
		HRESULT SetOkButtonLabel(LPCWSTR pszText);
		HRESULT SetFileNameLabel(LPCWSTR pszLabel);
		HRESULT GetResult(IShellItem* ppsi);
		HRESULT AddPlace(IShellItem psi, FDAP fdap);
		HRESULT SetDefaultExtension(LPCWSTR pszDefaultExtension);
		HRESULT Close(HRESULT hr);
		HRESULT SetClientGuid(REFGUID guid);
		HRESULT ClearClientData();
		HRESULT SetFilter(IShellItemFilter pFilter);
	}
	mixin DEFINE_IID!(IFileDialog, "42f85136-db7e-439c-85f1-e4075d135fc8");

	//(_WIN32_IE >= _WIN32_IE_IE70)
	//extern extern(C) const IID IID_IFileOperationProgressSink;
	interface IFileOperationProgressSink : IUnknown {
		public extern(Windows):
		HRESULT StartOperations();
		HRESULT FinishOperations(HRESULT hrResult);
		HRESULT PreRenameItem(DWORD dwFlags, IShellItem psiItem, LPCWSTR pszNewName);
		HRESULT PostRenameItem(DWORD dwFlags, IShellItem psiItem, LPCWSTR pszNewName, HRESULT hrRename, IShellItem psiNewlyCreated);
		HRESULT PreMoveItem(DWORD dwFlags, IShellItem psiItem, IShellItem psiDestinationFolder, LPCWSTR pszNewName);
		HRESULT PostMoveItem(DWORD dwFlags, IShellItem psiItem, IShellItem psiDestinationFolder, LPCWSTR pszNewName, HRESULT hrMove, IShellItem psiNewlyCreated);
		HRESULT PreCopyItem(DWORD dwFlags, IShellItem psiItem, IShellItem psiDestinationFolder, LPCWSTR pszNewName);
		HRESULT PostCopyItem(DWORD dwFlags, IShellItem psiItem, IShellItem psiDestinationFolder, LPCWSTR pszNewName, HRESULT hrCopy, IShellItem psiNewlyCreated);
		HRESULT PreDeleteItem(DWORD dwFlags, IShellItem psiItem);
		HRESULT PostDeleteItem(DWORD dwFlags, IShellItem psiItem, HRESULT hrDelete, IShellItem psiNewlyCreated);
		HRESULT PreNewItem(DWORD dwFlags, IShellItem psiDestinationFolder, LPCWSTR pszNewName);
		HRESULT PostNewItem(DWORD dwFlags, IShellItem psiDestinationFolder, LPCWSTR pszNewName, LPCWSTR pszTemplateName, DWORD dwFileAttributes, HRESULT hrNew, IShellItem psiNewItem);
		HRESULT UpdateProgress(UINT iWorkTotal, UINT iWorkSoFar);
		HRESULT ResetTimer();
		HRESULT PauseTimer();
		HRESULT ResumeTimer();
	}
	mixin DEFINE_IID!(IFileOperationProgressSink, "04b0f1a7-9490-44bc-96e1-4296a31252e2");


	//extern extern(C) const IID IID_IPropertyStore;
	interface IPropertyStore : IUnknown {
		public extern(Windows):
		HRESULT GetCount(DWORD* cProps);
		HRESULT GetAt(DWORD iProp, PROPERTYKEY* pkey);
		HRESULT GetValue(REFPROPERTYKEY key, PROPVARIANT* pv);
		HRESULT SetValue(REFPROPERTYKEY key, REFPROPVARIANT propvar);
		HRESULT Commit();
	}
	mixin DEFINE_IID!(IPropertyStore, "886d8eeb-8cf2-4446-8d02-cdba1dbdcf99");
	alias IPropertyStore LPPROPERTYSTORE;

	//extern extern(C) const IID IID_IPropertyDescriptionList;
	interface IPropertyDescriptionList : IUnknown {
		public extern(Windows):
		HRESULT GetCount(UINT* pcElem);
		HRESULT GetAt(UINT iElem, REFIID riid, void** ppv);
	}
	mixin DEFINE_IID!(IPropertyDescriptionList, "1f9fc1d0-c39b-4b26-817f-011967d3440e");

	//extern extern(C) const IID IID_IFileSaveDialog;
	interface IFileSaveDialog : IFileDialog {
		public extern(Windows):
		HRESULT SetSaveAsItem(IShellItem psi);
		HRESULT SetProperties(IPropertyStore pStore);
		HRESULT SetCollectedProperties(IPropertyDescriptionList pList, BOOL fAppendDefault);
		HRESULT GetProperties(IPropertyStore* ppStore);
		HRESULT ApplyProperties(IShellItem psi, IPropertyStore pStore, HWND hwnd, IFileOperationProgressSink pSink);
	}
	mixin DEFINE_IID!(IFileSaveDialog, "84bccd23-5fde-4cdb-aea4-af64b83d78ab");

	enum {
		SIATTRIBFLAGS_AND       = 0x1,
		SIATTRIBFLAGS_OR        = 0x2,
		SIATTRIBFLAGS_APPCOMPAT = 0x3,
		SIATTRIBFLAGS_MASK      = 0x3,
		SIATTRIBFLAGS_ALLITEMS  = 0x4000
	}
	alias int SIATTRIBFLAGS;

	struct PROPERTYKEY {
		GUID fmtid;
		DWORD pid;
	}

	enum {
		GPS_DEFAULT               = 0,
		GPS_HANDLERPROPERTIESONLY = 0x1,
		GPS_READWRITE             = 0x2,
		GPS_TEMPORARY             = 0x4,
		GPS_FASTPROPERTIESONLY    = 0x8,
		GPS_OPENSLOWITEM          = 0x10,
		GPS_DELAYCREATION         = 0x20,
		GPS_BESTEFFORT            = 0x40,
		GPS_NO_OPLOCK             = 0x80,
		GPS_MASK_VALID            = 0xff
	}
	alias int GETPROPERTYSTOREFLAGS;

	struct PROPVARIANT {
		// HACK (jcd) stripped	
	}
	alias PROPVARIANT* LPPROPVARIANT;
	alias const(PROPVARIANT)* REFPROPVARIANT;

	alias const(PROPERTYKEY)* REFPROPERTYKEY;

	//(NTDDI_VERSION >= NTDDI_WINXP)
	//extern extern(C) const IID IID_IEnumShellItems;
	interface IEnumShellItems : IUnknown {
		public extern(Windows):
		HRESULT Next(ULONG celt, IShellItem* rgelt, ULONG* pceltFetched);
		HRESULT Skip(ULONG celt);
		HRESULT Reset();
		HRESULT Clone(IEnumShellItems* ppenum);
	}
	mixin DEFINE_IID!(IEnumShellItems, "70629033-e363-4a28-a567-0db78006e6d7");

	//extern extern(C) const IID IID_IShellItemArray;
	interface IShellItemArray : IUnknown {
		public extern(Windows):
		HRESULT BindToHandler(IBindCtx pbc, REFGUID bhid, REFIID riid, void** ppvOut);
		HRESULT GetPropertyStore(GETPROPERTYSTOREFLAGS flags, REFIID riid, void** ppv);
		HRESULT GetPropertyDescriptionList(REFPROPERTYKEY keyType, REFIID riid, void** ppv);
		HRESULT GetAttributes(SIATTRIBFLAGS AttribFlags, SFGAOF sfgaoMask, SFGAOF* psfgaoAttribs);
		HRESULT GetCount(DWORD* pdwNumItems);
		HRESULT GetItemAt(DWORD dwIndex, IShellItem* ppsi);
		HRESULT EnumItems(IEnumShellItems* ppenumShellItems);
	}
	mixin DEFINE_IID!(IShellItemArray, "b63ea76d-1f85-456f-a19c-48159efa858b");

	//extern extern(C) const IID IID_IFileOpenDialog;
	interface IFileOpenDialog : IFileDialog {
		public extern(Windows):
		HRESULT GetResults(IShellItemArray* ppenum);
		HRESULT GetSelectedItems(IShellItemArray* ppsai);
	}
	mixin DEFINE_IID!(IFileOpenDialog, "d57c7288-d4ad-4768-be02-9d969532d960");

	interface FileOpenDialog : IFileDialog {
		public extern(Windows):
		HRESULT GetResults(IShellItemArray* ppenum);
		HRESULT GetSelectedItems(IShellItemArray* ppsai);
	}

	mixin DEFINE_IID!(FileOpenDialog, "DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7");
	

	//extern extern(C) const IID IID_IFileDialog2;
	interface IFileDialog2 : IFileDialog {
		public extern(Windows):
		HRESULT SetCancelButtonLabel(LPCWSTR pszLabel);
		HRESULT SetNavigationRoot(IShellItem psi);
	}
	mixin DEFINE_GUID!(IFileDialog2, "61744fc7-85b5-4791-a9b0-272276309b13");

	//pragma(lib, "comctl32");
	//pragma(lib , "shlwapi");
	//pragma(lib, "propsys");

	private __gshared HRESULT coInitialized =  -1;
	private HRESULT ensureCoInitialize()
	{
		import core.sys.windows.com;

		if (SUCCEEDED(coInitialized))
			return coInitialized;
		
		coInitialized = CoInitializeEx(null, COINIT_APARTMENTTHREADED | 
											 COINIT_DISABLE_OLE1DDE);
		return coInitialized;
	}

	shared static ~this()
	{
		if (SUCCEEDED(coInitialized))
			CoUninitialize();
		coInitialized = -1;
	}

	// Returns the selected path or null if cancelled.
	// also returns null on error and will log the error to dccore.log;
    string showSelectFolderDialogBasic(string startDir)
    {
		import core.sys.windows.com;
		import dccore.log;

		string result = null;

		HRESULT hr2 = ensureCoInitialize();

		if (!SUCCEEDED(hr2))
		{
			log.error("Cannot initialized COM");
			return result;
		}	
		
        // CoCreate the File Open Dialog object.
        IFileOpenDialog pfd = null;
		IUnknown un = null;
        const(GUID) g = CLSID_FileOpenDialog;
        const(GUID) g2 = CLSID_IFileOpenDialog;
		HRESULT hr = CoCreateInstance(&g,
                                      un,
                                      cast(uint)CLSCTX_INPROC_SERVER,
                                      &g2,
									  cast(void**)&pfd);
		// IID_PPV_ARGS(&pfd));
        if (SUCCEEDED(hr))
        {
			
			// Show the Open dialog box.
            hr = pfd.Show(null);
			if (SUCCEEDED(hr))
            {
				// Obtain the result once the user clicks
				// the 'Open' button.
				// The result is an IShellItem object.
				IShellItem psiResult;
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
						import std.utf;
						import core.stdc.wchar_;
						import platform.config;
						auto len = wcslen(pszFilePath);
						result = toUTF8(pszFilePath[0..len]).statFilePathCase;
						CoTaskMemFree(pszFilePath);
					}
					else
					{
						log.error("Cannot get path from open file dialog");
					}
					psiResult.Release();
				}
				else
				{
					log.error("Cannot get result from open file dialog");
				}
			}
			else
			{
				log.error("Cannot create show file dialog");
			}
            pfd.Release();
        }
		else
		{
			log.error("Cannot create open file dialog");
		}
        return result;
    }

}

		

/+


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
+/


version (linux)
{

    enum MessageBoxStyle
    {
        none,
        error = 1,
        yesNo = 2,
	modal = 4,       
	}

    int messageBox(string title, string message, MessageBoxStyle t)
    {
        string result = null;
   import std.process;
    import std.regex;

	string mode = t & MessageBoxStyle.yesNo ? "--question" : "--info";
	string prefix = t & MessageBoxStyle.error ? "Error: " : "";

    auto res = pipeShell("zenity " ~ mode ~ " --text=\"" ~ prefix ~ message ~ "\"");

    return wait(res.pid) == 0;
}

    string showSelectFolderDialogBasic(string startDir)
    {

        string result = null;
   import std.process;
    import std.regex;

    auto res = pipeShell("zenity --file-selection --directory", Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);

    foreach (line; res.stdout.byLine)
    {
	result = line.idup;
	break;
    }
    if ( wait(res.pid) != 0)
	result = "";

	return result;
}
}
