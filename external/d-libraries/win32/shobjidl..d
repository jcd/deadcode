/** shobjidl.d

Converted from 'shobjidl.h'.

Version: V7.0
Authors: Koji Kishita
*/
module win32.shobjidl;

import win32.sdkddkver;
import win32.windef;
import win32.wtypes;
import win32.guiddef;
import win32.unknwn;
import win32.shtypes;
import win32.shellapi;
import win32.objidl;
import win32.winbase;
import win32.shlobj;
import win32.rpcdcep;
import win32.oleidl;
import win32.oaidl;
import win32.prsht;
import win32.winuser;
import win32.propidl;
import win32.propkeydef;
import win32.wingdi;
import win32.commctrl;
import win32.servprov;
import win32.propsys;
import win32.comcat;
import win32.structuredquerycondition;
import win32.msxml;
import win32.objectarray;
import win32.winerror;
import win32.objbase;


extern(C){

enum {
	CMF_NORMAL            = 0x00000000,
	CMF_DEFAULTONLY       = 0x00000001,
	CMF_VERBSONLY         = 0x00000002,
	CMF_EXPLORE           = 0x00000004,
	CMF_NOVERBS           = 0x00000008,
	CMF_CANRENAME         = 0x00000010,
	CMF_NODEFAULT         = 0x00000020,
	CMF_INCLUDESTATIC     = 0x00000040, // (NTDDI_VERSION < NTDDI_VISTA)
	CMF_ITEMMENU          = 0x00000080, // (NTDDI_VERSION >= NTDDI_VISTA)
	CMF_EXTENDEDVERBS     = 0x00000100,
	CMF_DISABLEDVERBS     = 0x00000200, // (NTDDI_VERSION >= NTDDI_VISTA)
	CMF_ASYNCVERBSTATE    = 0x00000400,
	CMF_OPTIMIZEFORINVOKE = 0x00000800,
	CMF_SYNCCASCADEMENU   = 0x00001000,
	CMF_DONOTPICKDEFAULT  = 0x00002000,
	CMF_RESERVED          = 0xffff0000,
}

enum {
	GCS_VERBA     = 0x00000000,
	GCS_HELPTEXTA = 0x00000001,
	GCS_VALIDATEA = 0x00000002,
	GCS_VERBW     = 0x00000004,
	GCS_HELPTEXTW = 0x00000005,
	GCS_VALIDATEW = 0x00000006,
	GCS_VERBICONW = 0x00000014,
	GCS_UNICODE   = 0x00000004,
}

version(UNICODE){
	alias GCS_VERBW GCS_VERB;
	alias GCS_HELPTEXTW GCS_HELPTEXT;
	alias GCS_VALIDATEW GCS_VALIDATE;
}else{
	alias GCS_VERBA GCS_VERB;
	alias GCS_HELPTEXTA GCS_HELPTEXT;
	alias GCS_VALIDATEA GCS_VALIDATE;
}

const char* CMDSTR_NEWFOLDERA = "NewFolder";
const char* CMDSTR_VIEWLISTA = "ViewList";
const char* CMDSTR_VIEWDETAILSA = "ViewDetails";
const wchar* CMDSTR_NEWFOLDERW = "NewFolder";
const wchar* CMDSTR_VIEWLISTW  = "ViewList";
const wchar* CMDSTR_VIEWDETAILSW = "ViewDetails";

version(UNICODE){
	alias CMDSTR_NEWFOLDERW CMDSTR_NEWFOLDER;
	alias CMDSTR_VIEWLISTW CMDSTR_VIEWLIST;
	alias CMDSTR_VIEWDETAILSW CMDSTR_VIEWDETAILS;
}else{
	alias CMDSTR_NEWFOLDERA CMDSTR_NEWFOLDER;
	alias CMDSTR_VIEWLISTA CMDSTR_VIEWLIST;
	alias CMDSTR_VIEWDETAILSA CMDSTR_VIEWDETAILS;
}

alias SEE_MASK_HOTKEY CMIC_MASK_HOTKEY;
alias SEE_MASK_ICON CMIC_MASK_ICON;
alias SEE_MASK_FLAG_NO_UI CMIC_MASK_FLAG_NO_UI;
alias SEE_MASK_UNICODE CMIC_MASK_UNICODE;
alias SEE_MASK_NO_CONSOLE CMIC_MASK_NO_CONSOLE;
//alias SEE_MASK_HASLINKNAME CMIC_MASK_HASLINKNAME; // (NTDDI_VERSION < NTDDI_VISTA)
//alias SEE_MASK_HASTITLE CMIC_MASK_HASTITLE; // (NTDDI_VERSION < NTDDI_VISTA)
//alias SEE_MASK_FLAG_SEPVDM CMIC_MASK_FLAG_SEP_VDM;
alias SEE_MASK_ASYNCOK CMIC_MASK_ASYNCOK;
alias SEE_MASK_NOASYNC CMIC_MASK_NOASYNC; // (NTDDI_VERSION >= NTDDI_VISTA)
enum CMIC_MASK_SHIFT_DOWN  = 0x10000000; // (_WIN32_IE >= _WIN32_IE_IE501)
enum CMIC_MASK_CONTROL_DOWN = 0x40000000; // (_WIN32_IE >= _WIN32_IE_IE501)
alias SEE_MASK_FLAG_LOG_USAGE CMIC_MASK_FLAG_LOG_USAGE; // (_WIN32_IE >= 0x0560)
alias SEE_MASK_NOZONECHECKS CMIC_MASK_NOZONECHECKS;// (_WIN32_IE >= 0x0560)
enum CMIC_MASK_PTINVOKE = 0x20000000; // (_WIN32_IE >= _WIN32_IE_IE40)


align(8){
	struct CMINVOKECOMMANDINFO {
		DWORD cbSize;
		DWORD fMask;
		HWND hwnd;
		LPCSTR lpVerb;
		LPCSTR lpParameters;
		LPCSTR lpDirectory;
		int nShow;
		DWORD dwHotKey;
		HANDLE hIcon;
	}
	alias CMINVOKECOMMANDINFO* LPCMINVOKECOMMANDINFO;
	alias const(CMINVOKECOMMANDINFO)* PCCMINVOKECOMMANDINFO;

	struct CMINVOKECOMMANDINFOEX {
		DWORD cbSize;
		DWORD fMask;
		HWND hwnd;
		LPCSTR lpVerb;
		LPCSTR lpParameters;
		LPCSTR lpDirectory;
		int nShow;
		DWORD dwHotKey;
		HANDLE hIcon;
		LPCSTR lpTitle;
		LPCWSTR lpVerbW;
		LPCWSTR lpParametersW;
		LPCWSTR lpDirectoryW;
		LPCWSTR lpTitleW;
		POINT ptInvoke;
	}
	alias CMINVOKECOMMANDINFOEX* LPCMINVOKECOMMANDINFOEX;
	alias const(CMINVOKECOMMANDINFOEX)* PCCMINVOKECOMMANDINFOEX;
} // aligin(8)


//extern extern(C) const IID IID_IContextMenu;
interface IContextMenu : IUnknown {
public extern(Windows):
	HRESULT QueryContextMenu(HMENU hmenu, UINT indexMenu, UINT idCmdFirst, UINT idCmdLast, UINT uFlags);
	HRESULT InvokeCommand(CMINVOKECOMMANDINFO* pici);
	HRESULT GetCommandString(UINT_PTR idCmd, UINT uType, UINT* pReserved, LPSTR pszName, UINT cchMax);
}
mixin DEFINE_GUID!(IContextMenu, "000214e4-0000-0000-c000-000000000046");
alias IContextMenu LPCONTEXTMENU;

//extern extern(C) const IID IID_IContextMenu2;
interface IContextMenu2 : IContextMenu {
public extern(Windows):
	HRESULT HandleMenuMsg(UINT uMsg, WPARAM wParam, LPARAM lParam);
}
mixin DEFINE_IID!(IContextMenu2, "000214f4-0000-0000-c000-000000000046");
alias IContextMenu2 LPCONTEXTMENU2;

//extern extern(C) const IID IID_IContextMenu3;
interface IContextMenu3 : IContextMenu2 {
public extern(Windows):
	HRESULT HandleMenuMsg2(UINT uMsg, WPARAM wParam, LPARAM lParam, LRESULT* plResult);
}
mixin DEFINE_IID!(IContextMenu3, "BCFCE0A0-EC17-11d0-8D10-00A0C90F2719");
alias IContextMenu3 LPCONTEXTMENU3;

//extern extern(C) const IID IID_IExecuteCommand;
interface IExecuteCommand : IUnknown {
public extern(Windows):
	HRESULT SetKeyState(DWORD grfKeyState);
	HRESULT SetParameters(LPCWSTR pszParameters);
	HRESULT SetPosition(POINT pt);
	HRESULT SetShowWindow(int nShow);
	HRESULT SetNoShowUI(BOOL fNoShowUI);
	HRESULT SetDirectory(LPCWSTR pszDirectory);
	HRESULT Execute();
}
mixin DEFINE_IID!(IExecuteCommand, "7F9185B0-CB92-43c5-80A9-92277A4F7B54");

//extern extern(C) const IID IID_IPersistFolder;
interface IPersistFolder : IPersist {
public extern(Windows):
	HRESULT Initialize(PCIDLIST_ABSOLUTE pidl);
}
mixin DEFINE_IID!(IPersistFolder, "000214EA-0000-0000-C000-000000000046");
alias IPersistFolder LPPERSISTFOLDER;

enum {
	IRTIR_TASK_NOT_RUNNING = 0,
	IRTIR_TASK_RUNNING     = 1,
	IRTIR_TASK_SUSPENDED   = 2,
	IRTIR_TASK_PENDING     = 3,
	IRTIR_TASK_FINISHED    = 4,
}

//extern extern(C) const IID IID_IRunnableTask;
interface IRunnableTask : IUnknown {
public extern(Windows):
	HRESULT Run();
	HRESULT Kill(BOOL bWait);
	HRESULT Suspend();
	HRESULT Resume();
	ULONG IsRunning();
}
mixin DEFINE_IID!(IRunnableTask, "85788d00-6807-11d0-b810-00c04fd706ec");

alias GUID_NULL TOID_NULL;
enum {
	ITSAT_DEFAULT_LPARAM                = cast(DWORD_PTR)-1,
	ITSAT_DEFAULT_PRIORITY              = 0x10000000,
	ITSAT_MAX_PRIORITY                  = 0x7fffffff,
	ITSAT_MIN_PRIORITY                  = 0x00000000,
	ITSSFLAG_COMPLETE_ON_DESTROY        = 0x0000,
	ITSSFLAG_KILL_ON_DESTROY            = 0x0001,
	ITSSFLAG_FLAGS_MASK                 = 0x0003,
	ITSS_THREAD_DESTROY_DEFAULT_TIMEOUT = 10*1000,
	ITSS_THREAD_TERMINATE_TIMEOUT       = INFINITE,
	ITSS_THREAD_TIMEOUT_NO_CHANGE       = INFINITE - 1,
}

//extern extern(C) const IID IID_IShellTaskScheduler;
interface IShellTaskScheduler : IUnknown {
public extern(Windows):
	HRESULT AddTask(IRunnableTask prt, REFTASKOWNERID rtoid, DWORD_PTR lParam, DWORD dwPriority);
	HRESULT RemoveTasks(REFTASKOWNERID rtoid, DWORD_PTR lParam, BOOL bWaitIfRunning);
	UINT CountTasks(REFTASKOWNERID rtoid);
	HRESULT Status(DWORD dwReleaseStatus, DWORD dwThreadTimeout);
}
mixin DEFINE_IID!(IShellTaskScheduler, "6CCB7BE0-6807-11d0-B810-00C04FD706EC");
alias IID_IShellTaskScheduler SID_ShellTaskScheduler;

//extern extern(C) const IID IID_IQueryCodePage;
interface IQueryCodePage : IUnknown {
public extern(Windows):
	HRESULT GetCodePage(UINT* puiCodePage);
	HRESULT SetCodePage(UINT uiCodePage);
}
mixin DEFINE_IID!(IQueryCodePage, "C7B236CE-EE80-11D0-985F-006008059382");

//extern extern(C) const IID IID_IPersistFolder2;
interface IPersistFolder2 : IPersistFolder {
public extern(Windows):
	HRESULT GetCurFolder(PIDLIST_ABSOLUTE* ppidl);
}
mixin DEFINE_IID!(IPersistFolder2, "1AC3D9F0-175C-11d1-95BE-00609797EA4F");

//enum CSIDL_FLAG_PFTI_TRACKTARGET = CSIDL_FLAG_DONT_VERIFY; moved to shlobj.d

align(8)
struct PERSIST_FOLDER_TARGET_INFO {
	PIDLIST_ABSOLUTE pidlTargetFolder;
	WCHAR[260] szTargetParsingName;
	WCHAR[260] szNetworkProvider;
	DWORD dwAttributes;
	int csidl;
}

//extern extern(C) const IID IID_IPersistFolder3;
interface IPersistFolder3 : IPersistFolder2 {
public extern(Windows):
	HRESULT InitializeEx(IBindCtx pbc, PCIDLIST_ABSOLUTE pidlRoot, const(PERSIST_FOLDER_TARGET_INFO)* ppfti);
	HRESULT GetFolderTargetInfo(PERSIST_FOLDER_TARGET_INFO* ppfti);
}
mixin DEFINE_IID!(IPersistFolder3, "CEF04FDF-FE72-11d2-87A5-00C04F6837CF");

//extern extern(C) const IID IID_IPersistIDList;
interface IPersistIDList : IPersist {// (NTDDI_VERSION >= NTDDI_WINXP) || (_WIN32_IE >= _WIN32_IE_IE70)
public extern(Windows):
	HRESULT SetIDList(PCIDLIST_ABSOLUTE pidl);
	HRESULT GetIDList(PIDLIST_ABSOLUTE* ppidl);
}
mixin DEFINE_IID!(IPersistIDList, "1079acfc-29bd-11d3-8e0d-00c04f6837d5");

//extern extern(C) const IID IID_IEnumIDList;
interface IEnumIDList : IUnknown {
public extern(Windows):
	HRESULT Next(ULONG celt, PITEMID_CHILD* rgelt, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumIDList* ppenum);
}
mixin DEFINE_IID!(IEnumIDList, "000214F2-0000-0000-C000-000000000046");
alias IEnumIDList LPENUMIDLIST;

export extern(Windows){
	HRESULT IEnumIDList_RemoteNext_Proxy(IEnumIDList This, ULONG celt, PITEMID_CHILD* rgelt, ULONG* pceltFetched);
	void IEnumIDList_RemoteNext_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
}

//extern extern(C) const IID IID_IEnumFullIDList;
interface IEnumFullIDList : IUnknown {
public extern(Windows):
	HRESULT Next(ULONG celt, PIDLIST_ABSOLUTE* rgelt, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumFullIDList* ppenum);
}
mixin DEFINE_IID!(IEnumFullIDList, "d0191542-7954-4908-bc06-b2360bbe45ba");

export extern(Windows){
	HRESULT IEnumFullIDList_RemoteNext_Proxy(IEnumFullIDList This, ULONG celt, PIDLIST_ABSOLUTE* rgelt, ULONG* pceltFetched);
	void IEnumFullIDList_RemoteNext_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
}

enum {
	SHGDN_NORMAL        = 0,
	SHGDN_INFOLDER      = 0x1,
	SHGDN_FOREDITING    = 0x1000,
	SHGDN_FORADDRESSBAR = 0x4000,
	SHGDN_FORPARSING    = 0x8000
}
alias DWORD SHGDNF;

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

enum {
	SHCIDS_ALLFIELDS      = 0x80000000,
	SHCIDS_CANONICALONLY  = 0x10000000,
	SHCIDS_BITMASK        = 0xFFFF0000,
	SHCIDS_COLUMNMASK     = 0x0000FFFF,
	SFGAO_CANCOPY         = DROPEFFECT_COPY,
	SFGAO_CANMOVE         = DROPEFFECT_MOVE,
	SFGAO_CANLINK         = DROPEFFECT_LINK,
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

const wchar* STR_BIND_FORCE_FOLDER_SHORTCUT_RESOLVE = "Force Folder Shortcut Resolve";
const wchar* STR_AVOID_DRIVE_RESTRICTION_POLICY = "Avoid Drive Restriction Policy";
//const wchar* STR_AVOID_DRIVE_RESTRICTION_POLICY = "Avoid Drive Restriction Policy";
const wchar* STR_SKIP_BINDING_CLSID = "Skip Binding CLSID";
const wchar* STR_PARSE_PREFER_FOLDER_BROWSING = "Parse Prefer Folder Browsing";
const wchar* STR_DONT_PARSE_RELATIVE = "Don't Parse Relative";
const wchar* STR_PARSE_TRANSLATE_ALIASES = "Parse Translate Aliases";
const wchar* STR_PARSE_SKIP_NET_CACHE = "Skip Net Resource Cache";
const wchar* STR_PARSE_SHELL_PROTOCOL_TO_FILE_OBJECTS = "Parse Shell Protocol To File Objects";
//(_WIN32_IE >= 0x0700)
	const wchar* STR_TRACK_CLSID = "Track the CLSID";
	const wchar* STR_INTERNAL_NAVIGATE = "Internal Navigation";
	const wchar* STR_PARSE_PROPERTYSTORE = "DelegateNamedProperties";
	const wchar* STR_NO_VALIDATE_FILENAME_CHARS = "NoValidateFilenameChars";
	const wchar* STR_BIND_DELEGATE_CREATE_OBJECT = "Delegate Object Creation";
	const wchar* STR_PARSE_ALLOW_INTERNET_SHELL_FOLDERS = "Allow binding to Internet shell folder handlers and negate STR_PARSE_PREFER_WEB_BROWSING";
	const wchar* STR_PARSE_PREFER_WEB_BROWSING = "Do not bind to Internet shell folder handlers";
	const wchar* STR_PARSE_SHOW_NET_DIAGNOSTICS_UI = "Show network diagnostics UI";
	const wchar* STR_PARSE_DONT_REQUIRE_VALIDATED_URLS = "Do not require validated URLs";
	const wchar* STR_INTERNETFOLDER_PARSE_ONLY_URLMON_BINDABLE = "Validate URL";
//(NTDDI_VERSION >= NTDDI_WIN7)
	const wchar* STR_BIND_FOLDERS_READ_ONLY = "Folders As Read Only";
	const wchar* STR_BIND_FOLDER_ENUM_MODE = "Folder Enum Mode";
	enum {
		FEM_VIEWRESULT = 0,
		FEM_NAVIGATION = 1
	}
	alias int FOLDER_ENUM_MODE;

	//extern extern(C) const IID IID_IObjectWithFolderEnumMode;
	interface IObjectWithFolderEnumMode : IUnknown {
	public extern(Windows):
		HRESULT SetMode(FOLDER_ENUM_MODE feMode);
		HRESULT GetMode(FOLDER_ENUM_MODE* pfeMode);
	}
	mixin DEFINE_IID!(IObjectWithFolderEnumMode, "6a9d9026-0e6e-464c-b000-42ecc07de673");

	const wchar* STR_PARSE_WITH_EXPLICIT_PROGID = "ExplicitProgid";
	const wchar* STR_PARSE_WITH_EXPLICIT_ASSOCAPP = "ExplicitAssociationApp";
	const wchar* STR_PARSE_EXPLICIT_ASSOCIATION_SUCCESSFUL = "ExplicitAssociationSuccessful";
	const wchar* STR_PARSE_AND_CREATE_ITEM = "ParseAndCreateItem";

	//extern extern(C) const IID IID_IParseAndCreateItem;
	interface IParseAndCreateItem : IUnknown {
	public extern(Windows):
		HRESULT SetItem(IShellItem psi);
		HRESULT GetItem(REFIID riid, void** ppv);
	}
	mixin DEFINE_IID!(IParseAndCreateItem, "67efed0e-e827-4408-b493-78f3982b685c");

	const wchar* STR_ITEM_CACHE_CONTEXT = "ItemCacheContext";

//extern extern(C) const IID IID_IShellFolder;
interface IShellFolder : IUnknown {
public extern(Windows):
	HRESULT ParseDisplayName(HWND hwnd, IBindCtx pbc, LPWSTR pszDisplayName, ULONG* pchEaten, PIDLIST_RELATIVE* ppidl, ULONG* pdwAttributes);
	HRESULT EnumObjects(HWND hwnd, SHCONTF grfFlags, IEnumIDList* ppenumIDList);
	HRESULT BindToObject(PCUIDLIST_RELATIVE pidl, IBindCtx pbc, REFIID riid, void** ppv);
	HRESULT BindToStorage(PCUIDLIST_RELATIVE pidl, IBindCtx pbc, REFIID riid, void** ppv);
	HRESULT CompareIDs(LPARAM lParam, PCUIDLIST_RELATIVE pidl1, PCUIDLIST_RELATIVE pidl2);
	HRESULT CreateViewObject(HWND hwndOwner, REFIID riid, void** ppv);
	HRESULT GetAttributesOf(UINT cidl, PCUITEMID_CHILD_ARRAY apidl, SFGAOF* rgfInOut);
	HRESULT GetUIObjectOf(HWND hwndOwner, UINT cidl, PCUITEMID_CHILD_ARRAY apidl, REFIID riid, UINT* rgfReserved, void** ppv);
	HRESULT GetDisplayNameOf(PCUITEMID_CHILD pidl, SHGDNF uFlags, STRRET* pName);
	HRESULT SetNameOf(HWND hwnd, PCUITEMID_CHILD pidl, LPCWSTR pszName, SHGDNF uFlags, PITEMID_CHILD* ppidlOut);
}
mixin DEFINE_IID!(IShellFolder, "000214E6-0000-0000-C000-000000000046");
alias IShellFolder LPSHELLFOLDER;

export extern(Windows){
	HRESULT IShellFolder_RemoteSetNameOf_Proxy(IShellFolder This, HWND hwnd, PCUITEMID_CHILD pidl, LPCWSTR pszName, SHGDNF uFlags, PITEMID_CHILD* ppidlOut);
	void IShellFolder_RemoteSetNameOf_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
}

struct EXTRASEARCH {
	GUID guidSearch;
	WCHAR[80] wszFriendlyName;
	WCHAR[2084] wszUrl;
}
alias EXTRASEARCH* LPEXTRASEARCH;

//extern extern(C) const IID IID_IEnumExtraSearch;
interface IEnumExtraSearch : IUnknown {
public extern(Windows):
	HRESULT Next(ULONG celt, EXTRASEARCH* rgelt, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumExtraSearch* ppenum);
}
mixin DEFINE_IID!(IEnumExtraSearch, "0E700BE1-9DB6-11d1-A1CE-00C04FD75D13");
alias IEnumExtraSearch LPENUMEXTRASEARCH;

//extern extern(C) const IID IID_IShellFolder2;
interface IShellFolder2 : IShellFolder {
public extern(Windows):
	HRESULT GetDefaultSearchGUID(GUID* pguid);
	HRESULT EnumSearches(IEnumExtraSearch* ppenum);
	HRESULT GetDefaultColumn(DWORD dwRes, ULONG* pSort, ULONG* pDisplay);
	HRESULT GetDefaultColumnState(UINT iColumn, SHCOLSTATEF* pcsFlags);
	HRESULT GetDetailsEx( PCUITEMID_CHILD pidl, const(SHCOLUMNID)* pscid, VARIANT* pv);
	HRESULT GetDetailsOf(PCUITEMID_CHILD pidl, UINT iColumn, SHELLDETAILS* psd);
	HRESULT MapColumnToSCID(UINT iColumn, SHCOLUMNID* pscid);
}
mixin DEFINE_IID!(IShellFolder2, "93F2F68C-1D1B-11d3-A30E-00C04F79ABD1");

alias char* LPVIEWSETTINGS;

enum {
	FWF_NONE                = 0,
	FWF_AUTOARRANGE         = 0x1,
	FWF_ABBREVIATEDNAMES    = 0x2,
	FWF_SNAPTOGRID          = 0x4,
	FWF_OWNERDATA           = 0x8,
	FWF_BESTFITWINDOW       = 0x10,
	FWF_DESKTOP             = 0x20,
	FWF_SINGLESEL           = 0x40,
	FWF_NOSUBFOLDERS        = 0x80,
	FWF_TRANSPARENT         = 0x100,
	FWF_NOCLIENTEDGE        = 0x200,
	FWF_NOSCROLL            = 0x400,
	FWF_ALIGNLEFT           = 0x800,
	FWF_NOICONS             = 0x1000,
	FWF_SHOWSELALWAYS       = 0x2000,
	FWF_NOVISIBLE           = 0x4000,
	FWF_SINGLECLICKACTIVATE = 0x8000,
	FWF_NOWEBVIEW           = 0x10000,
	FWF_HIDEFILENAMES       = 0x20000,
	FWF_CHECKSELECT         = 0x40000,
	FWF_NOENUMREFRESH       = 0x80000,
	FWF_NOGROUPING          = 0x100000,
	FWF_FULLROWSELECT       = 0x200000,
	FWF_NOFILTERS           = 0x400000,
	FWF_NOCOLUMNHEADER      = 0x800000,
	FWF_NOHEADERINALLVIEWS  = 0x1000000,
	FWF_EXTENDEDTILES       = 0x2000000,
	FWF_TRICHECKSELECT      = 0x4000000,
	FWF_AUTOCHECKSELECT     = 0x8000000,
	FWF_NOBROWSERVIEWSTATE  = 0x10000000,
	FWF_SUBSETGROUPS        = 0x20000000,
	FWF_USESEARCHFOLDER     = 0x40000000,
	FWF_ALLOWRTLREADING     = 0x80000000
}
alias int FOLDERFLAGS;

enum {
	FVM_AUTO       = -1,
	FVM_FIRST      = 1,
	FVM_ICON       = 1,
	FVM_SMALLICON  = 2,
	FVM_LIST       = 3,
	FVM_DETAILS    = 4,
	FVM_THUMBNAIL  = 5,
	FVM_TILE       = 6,
	FVM_THUMBSTRIP = 7,
	FVM_CONTENT    = 8,
	FVM_LAST       = 8
}
alias int FOLDERVIEWMODE;

enum {//(NTDDI_VERSION >= NTDDI_VISTA)
	FLVM_UNSPECIFIED = -1,
	FLVM_FIRST       = 1,
	FLVM_DETAILS     = 1,
	FLVM_TILES       = 2,
	FLVM_ICONS       = 3,
	FLVM_LIST        = 4,
	FLVM_CONTENT     = 5,
	FLVM_LAST        = 5
}
alias int FOLDERLOGICALVIEWMODE;

struct FOLDERSETTINGS {
	UINT ViewMode;
	UINT fFlags;
}
alias FOLDERSETTINGS* LPFOLDERSETTINGS;
alias const(FOLDERSETTINGS)* LPCFOLDERSETTINGS;
alias FOLDERSETTINGS* PFOLDERSETTINGS;

enum {
	FVO_DEFAULT           = 0,
	FVO_VISTALAYOUT       = 0x1,
	FVO_CUSTOMPOSITION    = 0x2,
	FVO_CUSTOMORDERING    = 0x4,
	FVO_SUPPORTHYPERLINKS = 0x8,
	FVO_NOANIMATIONS      = 0x10,
	FVO_NOSCROLLTIPS      = 0x20
}
alias int FOLDERVIEWOPTIONS;

//extern extern(C) const IID IID_IFolderViewOptions;
interface IFolderViewOptions : IUnknown {
public extern(Windows):
	HRESULT SetFolderViewOptions(FOLDERVIEWOPTIONS fvoMask, FOLDERVIEWOPTIONS fvoFlags);
	HRESULT GetFolderViewOptions(FOLDERVIEWOPTIONS* pfvoFlags);
}
mixin DEFINE_IID!(IFolderViewOptions, "3cc974d2-b302-4d36-ad3e-06d93f695d3f");

enum {
	SVSI_DESELECT       = 0,
	SVSI_SELECT         = 0x1,
	SVSI_EDIT           = 0x3,
	SVSI_DESELECTOTHERS = 0x4,
	SVSI_ENSUREVISIBLE  = 0x8,
	SVSI_FOCUSED        = 0x10,
	SVSI_TRANSLATEPT    = 0x20,
	SVSI_SELECTIONMARK  = 0x40,
	SVSI_POSITIONITEM   = 0x80,
	SVSI_CHECK          = 0x100,
	SVSI_CHECK2         = 0x200,
	SVSI_KEYBOARDSELECT = 0x401,
	SVSI_NOTAKEFOCUS    = 0x40000000,
	SVSI_NOSTATECHANGE  = cast(UINT)0x80000000,
}
alias UINT SVSIF;

enum {
	SVGIO_BACKGROUND     = 0,
	SVGIO_SELECTION      = 0x1,
	SVGIO_ALLVIEW        = 0x2,
	SVGIO_CHECKED        = 0x3,
	SVGIO_TYPE_MASK      = 0xf,
	SVGIO_FLAG_VIEWORDER = 0x80000000
}
alias int SVGIO;

enum {
	SVUIA_DEACTIVATE       = 0,
	SVUIA_ACTIVATE_NOFOCUS = 1,
	SVUIA_ACTIVATE_FOCUS   = 2,
	SVUIA_INPLACEACTIVATE  = 3
}
alias int SVUIA_STATUS;

alias LPFNADDPROPSHEETPAGE LPFNSVADDPROPSHEETPAGE;

//extern extern(C) const IID IID_IShellView;
interface IShellView : IOleWindow {
public extern(Windows):
	HRESULT TranslateAccelerator(MSG* pmsg);
	HRESULT EnableModeless(BOOL fEnable);
	HRESULT UIActivate(UINT uState);
	HRESULT Refresh();
	HRESULT CreateViewWindow(IShellView psvPrevious, LPCFOLDERSETTINGS pfs, IShellBrowser psb, RECT* prcView, HWND* phWnd);
	HRESULT DestroyViewWindow();
	HRESULT GetCurrentInfo(LPFOLDERSETTINGS pfs);
	HRESULT AddPropertySheetPages(DWORD dwReserved, LPFNSVADDPROPSHEETPAGE pfn, LPARAM lparam);
	HRESULT SaveViewState();
	HRESULT SelectItem(PCUITEMID_CHILD pidlItem, SVSIF uFlags);
	HRESULT GetItemObject(UINT uItem, REFIID riid, void** ppv);
}
mixin DEFINE_IID!(IShellView, "000214E3-0000-0000-C000-000000000046");
alias IShellView LPSHELLVIEW;

alias GUID SHELLVIEWID;

enum {
	SV2GV_CURRENTVIEW = cast(UINT)-1,
	SV2GV_DEFAULTVIEW = cast(UINT)-2,
}

align(8)
struct SV2CVW2_PARAMS {
	DWORD cbSize;
	IShellView psvPrev;
	LPCFOLDERSETTINGS pfs;
	IShellBrowser psbOwner;
	RECT* prcView;
	const(SHELLVIEWID)* pvid;
	HWND hwndView;
}
alias SV2CVW2_PARAMS* LPSV2CVW2_PARAMS;

//extern extern(C) const IID IID_IShellView2;
interface IShellView2 : IShellView {
public extern(Windows):
	HRESULT GetView(SHELLVIEWID* pvid, ULONG uView);
	HRESULT CreateViewWindow2(LPSV2CVW2_PARAMS lpParams);
	HRESULT HandleRename(PCUITEMID_CHILD pidlNew);
	HRESULT SelectAndPositionItem(PCUITEMID_CHILD pidlItem, UINT uFlags, POINT* ppt);
}
mixin DEFINE_IID!(IShellView2, "88E39E80-3578-11CF-AE69-08002B2E1262");

//(NTDDI_VERSION >= NTDDI_VISTA)
	enum{
		SV3CVW3_DEFAULT          = 0,
		SV3CVW3_NONINTERACTIVE   = 0x1,
		SV3CVW3_FORCEVIEWMODE    = 0x2,
		SV3CVW3_FORCEFOLDERFLAGS = 0x4
	}
	alias DWORD SV3CVW3_FLAGS;

	//extern extern(C) const IID IID_IShellView3;
	interface IShellView3 : IShellView2 {
	public extern(Windows):
		HRESULT CreateViewWindow3(IShellBrowser psbOwner, IShellView psvPrev, SV3CVW3_FLAGS dwViewFlags, FOLDERFLAGS dwMask, FOLDERFLAGS dwFlags, FOLDERVIEWMODE fvMode, const(SHELLVIEWID)* pvid, const(RECT)* prcView, HWND* phwndView);
	}
	mixin DEFINE_IID!(IShellView3, "ec39fa88-f8af-41c5-8421-38bed28f4673");

//extern extern(C) const IID IID_IFolderView;
interface IFolderView : IUnknown {
public extern(Windows):
	HRESULT GetCurrentViewMode(UINT* pViewMode);
	HRESULT SetCurrentViewMode(UINT ViewMode);
	HRESULT GetFolder(REFIID riid, void** ppv);
	HRESULT Item(int iItemIndex, PITEMID_CHILD* ppidl);
	HRESULT ItemCount(UINT uFlags, int* pcItems);
	HRESULT Items(UINT uFlags, REFIID riid, void** ppv);
	HRESULT GetSelectionMarkedItem(int* piItem);
	HRESULT GetFocusedItem(int* piItem);
	HRESULT GetItemPosition(PCUITEMID_CHILD pidl, POINT* ppt);
	HRESULT GetSpacing(POINT* ppt);
	HRESULT GetDefaultSpacing(POINT* ppt);
	HRESULT GetAutoArrange();
	HRESULT SelectItem(int iItem, DWORD dwFlags);
	HRESULT SelectAndPositionItems(UINT cidl, PCUITEMID_CHILD_ARRAY apidl, POINT* apt, DWORD dwFlags);
}
mixin DEFINE_IID!(IFolderView, "cde725b0-ccc9-4519-917e-325d72fab4ce");
alias IID_IFolderView SID_SFolderView;

//(NTDDI_VERSION >= NTDDI_WIN7)
	//extern extern(C) const IID IID_ISearchBoxInfo;
	interface ISearchBoxInfo : IUnknown {
	public extern(Windows):
		HRESULT GetCondition(REFIID riid, void** ppv);
		HRESULT GetText(LPWSTR* ppsz);
	}
	mixin DEFINE_IID!(ISearchBoxInfo, "6af6e03f-d664-4ef4-9626-f7e0ed36755e");

//(NTDDI_VERSION >= NTDDI_VISTA) || (_WIN32_IE >= _WIN32_IE_IE70)
	enum {
		SORT_DESCENDING = -1,
		SORT_ASCENDING  = 1
	}
	alias int SORTDIRECTION;

	struct SORTCOLUMN {
		PROPERTYKEY propkey;
		SORTDIRECTION direction;
	}

	enum {
		FVST_EMPTYTEXT = 0
	}
	alias int FVTEXTTYPE;

	alias HRESULT DEPRECATED_HRESULT; //DEPRECATED_HRESULT HRESULT DECLSPEC_DEPRECATED

	//extern extern(C) const IID IID_IFolderView2;
	interface IFolderView2 : IFolderView {
	public extern(Windows):
		HRESULT SetGroupBy(REFPROPERTYKEY key, BOOL fAscending);
		HRESULT GetGroupBy(PROPERTYKEY* pkey, BOOL* pfAscending);
		DEPRECATED_HRESULT SetViewProperty(PCUITEMID_CHILD pidl, REFPROPERTYKEY propkey, REFPROPVARIANT propvar);
		DEPRECATED_HRESULT GetViewProperty(PCUITEMID_CHILD pidl, REFPROPERTYKEY propkey, PROPVARIANT* ppropvar);
		DEPRECATED_HRESULT SetTileViewProperties(PCUITEMID_CHILD pidl, LPCWSTR pszPropList);
		DEPRECATED_HRESULT SetExtendedTileViewProperties(PCUITEMID_CHILD pidl, LPCWSTR pszPropList);
		HRESULT SetText(FVTEXTTYPE iType, LPCWSTR pwszText);
		HRESULT SetCurrentFolderFlags(DWORD dwMask, DWORD dwFlags);
		HRESULT GetCurrentFolderFlags(DWORD* pdwFlags);
		HRESULT GetSortColumnCount(int* pcColumns);
		HRESULT SetSortColumns(const(SORTCOLUMN)* rgSortColumns, int cColumns);
		HRESULT GetSortColumns(SORTCOLUMN* rgSortColumns, int cColumns);
		HRESULT GetItem(int iItem, REFIID riid, void** ppv);
		HRESULT GetVisibleItem(int iStart, BOOL fPrevious, int* piItem);
		HRESULT GetSelectedItem(int iStart, int* piItem);
		HRESULT GetSelection(BOOL fNoneImpliesFolder, IShellItemArray* ppsia);
		HRESULT GetSelectionState(PCUITEMID_CHILD pidl, DWORD* pdwFlags);
		HRESULT InvokeVerbOnSelection(LPCSTR pszVerb);
		HRESULT SetViewModeAndIconSize(FOLDERVIEWMODE uViewMode, int iImageSize);
		HRESULT GetViewModeAndIconSize(FOLDERVIEWMODE* puViewMode, int* piImageSize);
		HRESULT SetGroupSubsetCount(UINT cVisibleRows);
		HRESULT GetGroupSubsetCount(UINT* pcVisibleRows);
		HRESULT SetRedraw(BOOL fRedrawOn);
		HRESULT IsMoveInSameFolder();
		HRESULT DoRename();
	}
	mixin DEFINE_IID!(IFolderView2, "1af3a467-214f-4298-908e-06b03e0b39f9");

	export extern(Windows){
		HRESULT IFolderView2_RemoteGetGroupBy_Proxy(IFolderView2 This, PROPERTYKEY* pkey, BOOL* pfAscending);
		void IFolderView2_RemoteGetGroupBy_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_IFolderViewSettings;
	interface IFolderViewSettings : IUnknown {
	public extern(Windows):
		HRESULT GetColumnPropertyList(REFIID riid, void** ppv);
		HRESULT GetGroupByProperty(PROPERTYKEY* pkey, BOOL* pfGroupAscending);
		HRESULT GetViewMode(FOLDERLOGICALVIEWMODE* plvm);
		HRESULT GetIconSize(UINT* puIconSize);
		HRESULT GetFolderFlags(FOLDERFLAGS* pfolderMask, FOLDERFLAGS* pfolderFlags);
		HRESULT GetSortColumns(SORTCOLUMN* rgSortColumns, UINT cColumnsIn, UINT* pcColumnsOut);
		HRESULT GetGroupSubsetCount(UINT* pcVisibleRows);
	}
	mixin DEFINE_IID!(IFolderViewSettings, "ae8c987d-8797-4ed3-be72-2a47dd938db0");

//(_WIN32_IE >= _WIN32_IE_IE70)
	//extern extern(C) const IID IID_IPreviewHandlerVisuals;
	interface IPreviewHandlerVisuals : IUnknown {
	public extern(Windows):
		HRESULT SetBackgroundColor(COLORREF color);
		HRESULT SetFont(const(LOGFONTW)* plf);
		HRESULT SetTextColor(COLORREF color);
	}
	mixin DEFINE_IID!(IPreviewHandlerVisuals, "196bf9a5-b346-4ef0-aa1e-5dcdb76768b1");

	enum {
		VPWF_DEFAULT    = 0,
		VPWF_ALPHABLEND = 0x1
	}
	alias int VPWATERMARKFLAGS;

	enum {
		VPCF_TEXT           = 1,
		VPCF_BACKGROUND     = 2,
		VPCF_SORTCOLUMN     = 3,
		VPCF_SUBTEXT        = 4,
		VPCF_TEXTBACKGROUND = 5
	} 
	alias int VPCOLORFLAGS;

	//extern extern(C) const IID IID_IVisualProperties;
	interface IVisualProperties : IUnknown {
	public extern(Windows):
		HRESULT SetWatermark(HBITMAP hbmp, VPWATERMARKFLAGS vpwf);
		HRESULT SetColor(VPCOLORFLAGS vpcf, COLORREF cr);
		HRESULT GetColor(VPCOLORFLAGS vpcf, COLORREF* pcr);
		HRESULT SetItemHeight(int cyItemInPixels);
		HRESULT GetItemHeight(int* cyItemInPixels);
		HRESULT SetFont(const(LOGFONTW)* plf, BOOL bRedraw);
		HRESULT GetFont(LOGFONTW* plf);
		HRESULT SetTheme(LPCWSTR pszSubAppName, LPCWSTR pszSubIdList);
	}
	mixin DEFINE_IID!(IVisualProperties, "e693cf68-d967-4112-8763-99172aee5e5a");

enum {
	CDBOSC_SETFOCUS    = 0x00000000,
	CDBOSC_KILLFOCUS   = 0x00000001,
	CDBOSC_SELCHANGE   = 0x00000002,
	CDBOSC_RENAME      = 0x00000003,
	CDBOSC_STATECHANGE = 0x00000004,
}

//extern extern(C) const IID IID_ICommDlgBrowser;
interface ICommDlgBrowser : IUnknown {
public extern(Windows):
	HRESULT OnDefaultCommand(IShellView ppshv);
	HRESULT OnStateChange(IShellView ppshv, ULONG uChange);
	HRESULT IncludeObject(IShellView ppshv, PCUITEMID_CHILD pidl);
}
mixin DEFINE_IID!(ICommDlgBrowser, "000214F1-0000-0000-C000-000000000046");
alias ICommDlgBrowser LPCOMMDLGBROWSER;
alias IID_ICommDlgBrowser SID_SExplorerBrowserFrame;

enum {
	CDB2N_CONTEXTMENU_DONE   = 0x00000001,
	CDB2N_CONTEXTMENU_START  = 0x00000002,
	CDB2GVF_SHOWALLFILES     = 0x00000001,
	//(NTDDI_VERSION >= NTDDI_VISTA)
		CDB2GVF_ISFILESAVE       = 0x00000002,
		CDB2GVF_ALLOWPREVIEWPANE = 0x00000004,
		CDB2GVF_NOSELECTVERB     = 0x00000008,
		CDB2GVF_NOINCLUDEITEM    = 0x00000010,
		CDB2GVF_ISFOLDERPICKER   = 0x00000020,
		CDB2GVF_ADDSHIELD        = 0x00000040,
}

//extern extern(C) const IID IID_ICommDlgBrowser2;
interface ICommDlgBrowser2 : ICommDlgBrowser {
public extern(Windows):
	HRESULT Notify(IShellView ppshv, DWORD dwNotifyType);
	HRESULT GetDefaultMenuText(IShellView ppshv, LPWSTR pszText, int cchMax);
	HRESULT GetViewFlags(DWORD* pdwFlags);
}
mixin DEFINE_IID!(ICommDlgBrowser2, "10339516-2894-11d2-9039-00C04F8EEB3E");
alias ICommDlgBrowser2 LPCOMMDLGBROWSER2;

//(_WIN32_IE >= _WIN32_IE_IE70)
	//extern extern(C) const IID IID_ICommDlgBrowser3;
	interface ICommDlgBrowser3 : ICommDlgBrowser2 {
	public extern(Windows):
		HRESULT OnColumnClicked(IShellView ppshv, int iColumn);
		HRESULT GetCurrentFilter(LPWSTR pszFileSpec, int cchFileSpec);
		HRESULT OnPreViewCreated(IShellView ppshv);
	}
	mixin DEFINE_IID!(ICommDlgBrowser3, "c8ad25a1-3294-41ee-8165-71174bd01c57");

	enum {
		CM_MASK_WIDTH        = 0x1,
		CM_MASK_DEFAULTWIDTH = 0x2,
		CM_MASK_IDEALWIDTH   = 0x4,
		CM_MASK_NAME         = 0x8,
		CM_MASK_STATE        = 0x10
	}
	alias int CM_MASK;

	enum {
		CM_STATE_NONE               = 0,
		CM_STATE_VISIBLE            = 0x1,
		CM_STATE_FIXEDWIDTH         = 0x2,
		CM_STATE_NOSORTBYFOLDERNESS = 0x4,
		CM_STATE_ALWAYSVISIBLE      = 0x8
	}
	alias int CM_STATE;

	enum {
		CM_ENUM_ALL     = 0x1,
		CM_ENUM_VISIBLE = 0x2
	}
	alias int CM_ENUM_FLAGS;

	enum {
		CM_WIDTH_USEDEFAULT = -1,
		CM_WIDTH_AUTOSIZE   = -2
	}
	alias int CM_SET_WIDTH_VALUE;

	struct CM_COLUMNINFO {
		DWORD cbSize;
		DWORD dwMask;
		DWORD dwState;
		UINT uWidth;
		UINT uDefaultWidth;
		UINT uIdealWidth;
		WCHAR[80] wszName;
	}

	//extern extern(C) const IID IID_IColumnManager;
	interface IColumnManager : IUnknown {
	public extern(Windows):
		HRESULT SetColumnInfo(REFPROPERTYKEY propkey, const(CM_COLUMNINFO)* pcmci);
		HRESULT GetColumnInfo( REFPROPERTYKEY propkey, CM_COLUMNINFO* pcmci);
		HRESULT GetColumnCount(CM_ENUM_FLAGS dwFlags, UINT* puCount);
		HRESULT GetColumns(CM_ENUM_FLAGS dwFlags, PROPERTYKEY* rgkeyOrder, UINT cColumns);
		HRESULT SetColumns(const(PROPERTYKEY)* rgkeyOrder, UINT cVisible);
	}
	mixin DEFINE_IID!(IColumnManager, "d8ec27bb-3f3b-4042-b10a-4acfd924d453");

//extern extern(C) const IID IID_IFolderFilterSite;
interface IFolderFilterSite : IUnknown {
public extern(Windows):
	HRESULT SetFilter(IUnknown punk);
}
mixin DEFINE_IID!(IFolderFilterSite, "C0A651F5-B48B-11d2-B5ED-006097C686F6");

//extern extern(C) const IID IID_IFolderFilter;
interface IFolderFilter : IUnknown {
public extern(Windows):
	HRESULT ShouldShow(IShellFolder psf, PCIDLIST_ABSOLUTE pidlFolder, PCUITEMID_CHILD pidlItem);
	HRESULT GetEnumFlags(IShellFolder psf, PCIDLIST_ABSOLUTE pidlFolder, HWND* phwnd, DWORD* pgrfFlags);
}
mixin DEFINE_IID!(IFolderFilter, "9CC22886-DC8E-11d2-B1D0-00C04F8EEB3E");

//extern extern(C) const IID IID_IInputObjectSite;
interface IInputObjectSite : IUnknown {
public extern(Windows):
	HRESULT OnFocusChangeIS(IUnknown punkObj, BOOL fSetFocus);
}
mixin DEFINE_IID!(IInputObjectSite, "F1DB8392-7331-11D0-8C99-00A0C92DBFE8");

//extern extern(C) const IID IID_IInputObject;
interface IInputObject : IUnknown {
public extern(Windows):
	HRESULT UIActivateIO(BOOL fActivate, MSG* pMsg);
	HRESULT HasFocusIO();
	HRESULT TranslateAcceleratorIO(MSG* pMsg);
}
mixin DEFINE_IID!(IInputObject, "68284fAA-6A48-11D0-8c78-00C04fd918b4");

//extern extern(C) const IID IID_IInputObject2;
interface IInputObject2 : IInputObject {
public extern(Windows):
	HRESULT TranslateAcceleratorGlobal(MSG* pMsg);
}
mixin DEFINE_IID!(IInputObject2, "6915C085-510B-44cd-94AF-28DFA56CF92B");

//extern extern(C) const IID IID_IShellIcon;
interface IShellIcon : IUnknown {
public extern(Windows):
	HRESULT GetIconOf(PCUITEMID_CHILD pidl, UINT flags, int* pIconIndex);
}
mixin DEFINE_IID!(IShellIcon, "000214E5-0000-0000-C000-000000000046");

enum {
	SBSP_DEFBROWSER         = 0x0000,
	SBSP_SAMEBROWSER        = 0x0001,
	SBSP_NEWBROWSER         = 0x0002,
	SBSP_DEFMODE            = 0x0000,
	SBSP_OPENMODE           = 0x0010,
	SBSP_EXPLOREMODE        = 0x0020,
	SBSP_HELPMODE           = 0x0040,
	SBSP_NOTRANSFERHIST     = 0x0080,
	SBSP_ABSOLUTE           = 0x0000,
	SBSP_RELATIVE           = 0x1000,
	SBSP_PARENT             = 0x2000,
	SBSP_NAVIGATEBACK       = 0x4000,
	SBSP_NAVIGATEFORWARD    = 0x8000,
	SBSP_ALLOW_AUTONAVIGATE = 0x00010000,
	//(NTDDI_VERSION >= NTDDI_VISTA)
		SBSP_KEEPSAMETEMPLATE  = 0x00020000,
		SBSP_KEEPWORDWHEELTEXT = 0x00040000,
		SBSP_ACTIVATE_NOFOCUS  = 0x00080000,
		SBSP_CREATENOHISTORY   = 0x00100000,
		SBSP_PLAYNOSOUND       = 0x00200000,
	SBSP_CALLERUNTRUSTED      = 0x00800000,
	SBSP_TRUSTFIRSTDOWNLOAD   = 0x01000000,
	SBSP_UNTRUSTEDFORDOWNLOAD = 0x02000000,
	SBSP_NOAUTOSELECT         = 0x04000000,
	SBSP_WRITENOHISTORY       = 0x08000000,
	SBSP_TRUSTEDFORACTIVEX    = 0x10000000,
	//(_WIN32_IE >= _WIN32_IE_IE70)
		SBSP_FEEDNAVIGATION = 0x20000000,
	SBSP_REDIRECT              = 0x40000000,
	SBSP_INITIATEDBYHLINKFRAME = 0x80000000,
	FCW_STATUS                 = 0x0001,
	FCW_TOOLBAR                = 0x0002,
	FCW_TREE                   = 0x0003,
	FCW_INTERNETBAR            = 0x0006,
	FCW_PROGRESS               = 0x0008,
	FCT_MERGE                  = 0x0001,
	FCT_CONFIGABLE             = 0x0002,
	FCT_ADDTOEND               = 0x0004,
}

alias LPTBBUTTON LPTBBUTTONSB;

//extern extern(C) const IID IID_IShellBrowser;
interface IShellBrowser : IOleWindow {
public extern(Windows):
	HRESULT InsertMenusSB(HMENU hmenuShared, LPOLEMENUGROUPWIDTHS lpMenuWidths);
	HRESULT SetMenuSB(HMENU hmenuShared, HOLEMENU holemenuRes, HWND hwndActiveObject);
	HRESULT RemoveMenusSB(HMENU hmenuShared);
	HRESULT SetStatusTextSB(LPCWSTR pszStatusText);
	HRESULT EnableModelessSB(BOOL fEnable);
	HRESULT TranslateAcceleratorSB(MSG* pmsg, WORD wID);
	HRESULT BrowseObject(PCUIDLIST_RELATIVE pidl, UINT wFlags);
	HRESULT GetViewStateStream(DWORD grfMode, IStream* ppStrm);
	HRESULT GetControlWindow(UINT id, HWND* phwnd);
	HRESULT SendControlMsg(UINT id, UINT uMsg, WPARAM wParam, LPARAM lParam, LRESULT* pret);
	HRESULT QueryActiveShellView(IShellView* ppshv);
	HRESULT OnViewWindowActive(IShellView pshv);
	HRESULT SetToolbarItems(LPTBBUTTONSB lpButtons, UINT nButtons, UINT uFlags);
}
mixin DEFINE_IID!(IShellBrowser, "000214E2-0000-0000-C000-000000000046");
alias IShellBrowser LPSHELLBROWSER;

//extern extern(C) const IID IID_IProfferService;
interface IProfferService : IUnknown {
public extern(Windows):
	HRESULT ProfferService(REFGUID guidService, IServiceProvider psp, DWORD* pdwCookie);
	HRESULT RevokeService(DWORD dwCookie);
}
mixin DEFINE_IID!(IProfferService, "cb728b20-f786-11ce-92ad-00aa00a74cd0");

alias IID_IProfferService SID_SProfferService;
const wchar* STR_DONT_RESOLVE_LINK = "Don't Resolve Link";
const wchar* STR_GET_ASYNC_HANDLER = "GetAsyncHandler";

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

export extern(Windows) PIDLIST_ABSOLUTE SHSimpleIDListFromPath(LPCWSTR pszPath);

static if(_WIN32_IE >= _WIN32_IE_IE70){
	export extern(Windows){
		HRESULT SHCreateItemFromIDList(PCIDLIST_ABSOLUTE pidl, REFIID riid, void** ppv);
		HRESULT SHCreateItemFromParsingName(PCWSTR pszPath, IBindCtx pbc, REFIID riid, void** ppv);
		HRESULT SHCreateItemWithParent(PCIDLIST_ABSOLUTE pidlParent, IShellFolder psfParent, PCUITEMID_CHILD pidl, REFIID riid, void** ppvItem);
		HRESULT SHCreateItemFromRelativeName(IShellItem psiParent, PCWSTR pszName, IBindCtx pbc, REFIID riid, void** ppv);
	}
}
static if(NTDDI_VERSION >= NTDDI_VISTA){
	export extern(Windows){
		HRESULT SHCreateItemInKnownFolder(REFKNOWNFOLDERID kfid, DWORD dwKFFlags, PCWSTR pszItem, REFIID riid, void** ppv);
		HRESULT SHGetIDListFromObject(IUnknown punk, PIDLIST_ABSOLUTE* ppidl);
		HRESULT SHGetItemFromObject(IUnknown punk, REFIID riid, void** ppv);
		HRESULT SHGetPropertyStoreFromIDList(PCIDLIST_ABSOLUTE pidl, GETPROPERTYSTOREFLAGS flags, REFIID riid, void** ppv);
		HRESULT SHGetPropertyStoreFromParsingName(PCWSTR pszPath, IBindCtx pbc, GETPROPERTYSTOREFLAGS flags, REFIID riid, void** ppv);
		HRESULT SHGetNameFromIDList(PCIDLIST_ABSOLUTE pidl, SIGDN sigdnName, PWSTR* ppszName);
	}
}
//(NTDDI_VERSION >= NTDDI_WIN7)
	enum{
		DOGIF_DEFAULT       = 0,
		DOGIF_TRAVERSE_LINK = 0x1,
		DOGIF_NO_HDROP      = 0x2,
		DOGIF_NO_URL        = 0x4,
		DOGIF_ONLY_IF_ONE   = 0x8
	 }
	 alias int DATAOBJ_GET_ITEM_FLAGS;

static if(NTDDI_VERSION >= NTDDI_WIN7){
	export extern(Windows){
		HRESULT SHGetItemFromDataObject(IDataObject pdtobj, DATAOBJ_GET_ITEM_FLAGS dwFlags, REFIID riid, void** ppv);
	}
}

const wchar* STR_GPS_HANDLERPROPERTIESONLY = "GPS_HANDLERPROPERTIESONLY";;
const wchar* STR_GPS_FASTPROPERTIESONLY = "GPS_FASTPROPERTIESONLY";
const wchar* STR_GPS_OPENSLOWITEM = "GPS_OPENSLOWITEM";
const wchar* STR_GPS_DELAYCREATION = "GPS_DELAYCREATION";
const wchar* STR_GPS_BESTEFFORT = "GPS_BESTEFFORT";
const wchar* STR_GPS_NO_OPLOCK = "GPS_NO_OPLOCK";

//extern extern(C) const IID IID_IShellItem2;
interface IShellItem2 : IShellItem {
public extern(Windows):
	HRESULT GetPropertyStore(GETPROPERTYSTOREFLAGS flags, REFIID riid, void** ppv);
	HRESULT GetPropertyStoreWithCreateObject(GETPROPERTYSTOREFLAGS flags, IUnknown punkCreateObject, REFIID riid, void** ppv);
	HRESULT GetPropertyStoreForKeys(const(PROPERTYKEY)* rgKeys, UINT cKeys, GETPROPERTYSTOREFLAGS flags, REFIID riid, void** ppv);
	HRESULT GetPropertyDescriptionList(REFPROPERTYKEY keyType, REFIID riid, void** ppv);
	HRESULT Update(IBindCtx pbc);
	HRESULT GetProperty(REFPROPERTYKEY key, PROPVARIANT* ppropvar);
	HRESULT GetCLSID(REFPROPERTYKEY key, CLSID* pclsid);
	HRESULT GetFileTime(REFPROPERTYKEY key, FILETIME* pft);
	HRESULT GetInt32(REFPROPERTYKEY key, int* pi);
	HRESULT GetString(REFPROPERTYKEY key, LPWSTR* ppsz);
	HRESULT GetUInt32(REFPROPERTYKEY key, ULONG* pui);
	HRESULT GetUInt64(REFPROPERTYKEY key, ULONGLONG* pull);
	HRESULT GetBool(REFPROPERTYKEY key, BOOL* pf);
}
mixin DEFINE_IID!(IShellItem2, "7e9fb0d3-919f-4307-ab2e-9b1860310c93");

enum {
	SIIGBF_RESIZETOFIT   = 0,
	SIIGBF_BIGGERSIZEOK  = 0x1,
	SIIGBF_MEMORYONLY    = 0x2,
	SIIGBF_ICONONLY      = 0x4,
	SIIGBF_THUMBNAILONLY = 0x8,
	SIIGBF_INCACHEONLY   = 0x10
}
alias int SIIGBF;

//extern extern(C) const IID IID_IShellItemImageFactory;
interface IShellItemImageFactory : IUnknown {
public extern(Windows):
	HRESULT GetImage(SIZE size, SIIGBF flags, HBITMAP* phbm);
}
mixin DEFINE_IID!(IShellItemImageFactory, "bcc18b79-ba16-442f-80c4-8a59c30c463b");

//extern extern(C) const IID IID_IUserAccountChangeCallback;
interface IUserAccountChangeCallback : IUnknown {
public extern(Windows):
	HRESULT OnPictureChange(LPCWSTR pszUserName);
}
mixin DEFINE_IID!(IUserAccountChangeCallback, "a561e69a-b4b8-4113-91a5-64c6bcca3430");

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

static if(NTDDI_VERSION >= NTDDI_WINXP){
	export extern(Windows){
		HRESULT IEnumShellItems_RemoteNext_Proxy(IEnumShellItems This, ULONG celt, IShellItem* rgelt, ULONG* pceltFetched);
		void IEnumShellItems_RemoteNext_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}
}

	alias GUID STGTRANSCONFIRMATION;
	alias GUID* LPSTGTRANSCONFIRMATION;

	enum {
		STGOP_MOVE            = 1,
		STGOP_COPY            = 2,
		STGOP_SYNC            = 3,
		STGOP_REMOVE          = 5,
		STGOP_RENAME          = 6,
		STGOP_APPLYPROPERTIES = 8,
		STGOP_NEW             = 10
	}
	alias int STGOP;


enum {
	TSF_NORMAL                     = 0,
	TSF_FAIL_EXIST                 = 0,
	TSF_RENAME_EXIST               = 0x1,
	TSF_OVERWRITE_EXIST            = 0x2,
	TSF_ALLOW_DECRYPTION           = 0x4,
	TSF_NO_SECURITY                = 0x8,
	TSF_COPY_CREATION_TIME         = 0x10,
	TSF_COPY_WRITE_TIME            = 0x20,
	TSF_USE_FULL_ACCESS            = 0x40,
	TSF_DELETE_RECYCLE_IF_POSSIBLE = 0x80,
	TSF_COPY_HARD_LINK             = 0x100,
	TSF_COPY_LOCALIZED_NAME        = 0x200,
	TSF_MOVE_AS_COPY_DELETE        = 0x400,
	TSF_SUSPEND_SHELLEVENTS        = 0x800
}
alias int TRANSFER_SOURCE_FLAGS;

//(_WIN32_IE >= _WIN32_IE_IE70)
	enum {
		TS_NONE          = 0,
		TS_PERFORMING    = 0x1,
		TS_PREPARING     = 0x2,
		TS_INDETERMINATE = 0x4
	}
	alias DWORD TRANSFER_ADVISE_STATE;

	//extern extern(C) const IID IID_ITransferAdviseSink;
	interface ITransferAdviseSink : IUnknown {
	public extern(Windows):
		HRESULT UpdateProgress(ULONGLONG ullSizeCurrent, ULONGLONG ullSizeTotal, int nFilesCurrent, int nFilesTotal, int nFoldersCurrent, int nFoldersTotal);
		HRESULT UpdateTransferState(TRANSFER_ADVISE_STATE ts);
		HRESULT ConfirmOverwrite(IShellItem psiSource, IShellItem psiDestParent, LPCWSTR pszName);
		HRESULT ConfirmEncryptionLoss(IShellItem psiSource);
		HRESULT FileFailure(IShellItem psi, LPCWSTR pszItem, HRESULT hrError, LPWSTR pszRename, ULONG cchRename);
		HRESULT SubStreamFailure(IShellItem psi, LPCWSTR pszStreamName, HRESULT hrError);
		HRESULT PropertyFailure(IShellItem psi, const(PROPERTYKEY)* pkey, HRESULT hrError);
	}
	mixin DEFINE_IID!(ITransferAdviseSink, "d594d0d8-8da7-457b-b3b4-ce5dbaac0b88");

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_ITransferSource;
	interface ITransferSource : IUnknown {
	public extern(Windows):
		HRESULT Advise(ITransferAdviseSink psink, DWORD* pdwCookie);
		HRESULT Unadvise(DWORD dwCookie);
		HRESULT SetProperties(IPropertyChangeArray pproparray);
		HRESULT OpenItem(IShellItem psi, TRANSFER_SOURCE_FLAGS flags, REFIID riid, void** ppv);
		HRESULT MoveItem(IShellItem psi, IShellItem psiParentDst, LPCWSTR pszNameDst, TRANSFER_SOURCE_FLAGS flags, IShellItem* ppsiNew);
		HRESULT RecycleItem(IShellItem psiSource, IShellItem psiParentDest, TRANSFER_SOURCE_FLAGS flags, IShellItem* ppsiNewDest);
		HRESULT RemoveItem(IShellItem psiSource, TRANSFER_SOURCE_FLAGS flags);
		HRESULT RenameItem(IShellItem psiSource, LPCWSTR pszNewName, TRANSFER_SOURCE_FLAGS flags, IShellItem* ppsiNewDest);
		HRESULT LinkItem(IShellItem psiSource, IShellItem psiParentDest, LPCWSTR pszNewName, TRANSFER_SOURCE_FLAGS flags, IShellItem* ppsiNewDest);
		HRESULT ApplyPropertiesToItem(IShellItem psiSource, IShellItem* ppsiNew);
		HRESULT GetDefaultDestinationName(IShellItem psiSource, IShellItem psiParentDest, LPWSTR* ppszDestinationName);
		HRESULT EnterFolder(IShellItem psiChildFolderDest);
		HRESULT LeaveFolder(IShellItem psiChildFolderDest);
	}
	mixin DEFINE_IID!(ITransferSource, "00adb003-bde9-45c6-8e29-d09f9353e108");

struct SHELL_ITEM_RESOURCE {
	GUID guidType;
	WCHAR[260] szName;
}

//extern extern(C) const IID IID_IEnumResources;
interface IEnumResources : IUnknown {
public extern(Windows):
	HRESULT Next(ULONG celt, SHELL_ITEM_RESOURCE* psir, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumResources* ppenumr);
}
mixin DEFINE_IID!(IEnumResources, "2dd81fe3-a83c-4da9-a330-47249d345ba1");

//extern extern(C) const IID IID_IShellItemResources;
interface IShellItemResources : IUnknown {
public extern(Windows):
	HRESULT GetAttributes(DWORD* pdwAttributes);
	HRESULT GetSize(ULONGLONG* pullSize);
	HRESULT GetTimes(FILETIME* pftCreation, FILETIME* pftWrite, FILETIME* pftAccess);
	HRESULT SetTimes(const(FILETIME)* pftCreation, const(FILETIME)* pftWrite, const(FILETIME)* pftAccess);
	HRESULT GetResourceDescription(const(SHELL_ITEM_RESOURCE)* pcsir, LPWSTR* ppszDescription);
	HRESULT EnumResources(IEnumResources* ppenumr);
	HRESULT SupportsResource(const(SHELL_ITEM_RESOURCE)* pcsir);
	HRESULT OpenResource(const(SHELL_ITEM_RESOURCE)* pcsir, REFIID riid, void** ppv);
	HRESULT CreateResource(const(SHELL_ITEM_RESOURCE)* pcsir, REFIID riid, void** ppv);
	HRESULT MarkForDelete();
}
mixin DEFINE_IID!(IShellItemResources, "ff5693be-2ce0-4d48-b5c5-40817d1acdb9");

//extern extern(C) const IID IID_ITransferDestination;
interface ITransferDestination : IUnknown {
public extern(Windows):
	HRESULT Advise(ITransferAdviseSink psink, DWORD* pdwCookie);
	HRESULT Unadvise(DWORD dwCookie);
	HRESULT CreateItem(LPCWSTR pszName, DWORD dwAttributes, ULONGLONG ullSize, TRANSFER_SOURCE_FLAGS flags, REFIID riidItem, void** ppvItem, REFIID riidResources, void** ppvResources);
}
mixin DEFINE_IID!(ITransferDestination, "48addd32-3ca5-4124-abe3-b5a72531b207");

//extern extern(C) const IID IID_IStreamAsync;
interface IStreamAsync : IStream {
public extern(Windows):
	HRESULT ReadAsync(void* pv, DWORD cb, LPDWORD pcbRead, LPOVERLAPPED lpOverlapped);
	HRESULT WriteAsync(const(void)* lpBuffer, DWORD cb, LPDWORD pcbWritten, LPOVERLAPPED lpOverlapped);
	HRESULT OverlappedResult(LPOVERLAPPED lpOverlapped, LPDWORD lpNumberOfBytesTransferred, BOOL bWait);
	HRESULT CancelIo();
}
mixin DEFINE_IID!(IStreamAsync, "fe0b6665-e0ca-49b9-a178-2b5cb48d92a5");

//extern extern(C) const IID IID_IStreamUnbufferedInfo;
interface IStreamUnbufferedInfo : IUnknown {
public extern(Windows):
	HRESULT GetSectorSize(ULONG* pcbSectorSize);
}
mixin DEFINE_IID!(IStreamUnbufferedInfo, "8a68fdda-1fdc-4c20-8ceb-416643b5a625");

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


enum {
	SIATTRIBFLAGS_AND       = 0x1,
	SIATTRIBFLAGS_OR        = 0x2,
	SIATTRIBFLAGS_APPCOMPAT = 0x3,
	SIATTRIBFLAGS_MASK      = 0x3,
	SIATTRIBFLAGS_ALLITEMS  = 0x4000
}
alias int SIATTRIBFLAGS;

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

static if(_WIN32_IE >= _WIN32_IE_IE70){
	export extern(Windows){
		HRESULT SHCreateShellItemArray(PCIDLIST_ABSOLUTE pidlParent, IShellFolder psf, UINT cidl, PCUITEMID_CHILD_ARRAY ppidl, IShellItemArray* ppsiItemArray);
		HRESULT SHCreateShellItemArrayFromDataObject(IDataObject pdo, REFIID riid, void** ppv);
		HRESULT SHCreateShellItemArrayFromIDLists(UINT cidl, PCIDLIST_ABSOLUTE_ARRAY rgpidl, IShellItemArray* ppsiItemArray);
		HRESULT SHCreateShellItemArrayFromShellItem(IShellItem psi, REFIID riid, void** ppv);
	}
}

//extern extern(C) const IID IID_IInitializeWithItem;
interface IInitializeWithItem : IUnknown {
public extern(Windows):
	HRESULT Initialize(IShellItem psi, DWORD grfMode);
}
mixin DEFINE_IID!(IInitializeWithItem, "7f73be3f-fb79-493c-a6c7-7ee14e245841");

//extern extern(C) const IID IID_IObjectWithSelection;
interface IObjectWithSelection : IUnknown {
public extern(Windows):
	HRESULT SetSelection(IShellItemArray psia);
	HRESULT GetSelection(REFIID riid, void** ppv);
}
mixin DEFINE_IID!(IObjectWithSelection, "1c9cd5bb-98e9-4491-a60f-31aacc72b83c");

//extern extern(C) const IID IID_IObjectWithBackReferences;
interface IObjectWithBackReferences : IUnknown {
public extern(Windows):
	HRESULT RemoveBackReferences();
}
mixin DEFINE_IID!(IObjectWithBackReferences, "321a6a6a-d61f-4bf3-97ae-14be2986bb36");

enum {
	PUIFNF_DEFAULT  = 0,
	PUIFNF_MNEMONIC = 0x1
}
alias DWORD PROPERTYUI_NAME_FLAGS;

enum {
	PUIF_DEFAULT          = 0,
	PUIF_RIGHTALIGN       = 0x1,
	PUIF_NOLABELININFOTIP = 0x2
}
alias DWORD PROPERTYUI_FLAGS;

enum {
	PUIFFDF_DEFAULT      = 0,
	PUIFFDF_RIGHTTOLEFT  = 0x1,
	PUIFFDF_SHORTFORMAT  = 0x2,
	PUIFFDF_NOTIME       = 0x4,
	PUIFFDF_FRIENDLYDATE = 0x8
}
alias DWORD PROPERTYUI_FORMAT_FLAGS;

//extern extern(C) const IID IID_IPropertyUI;
interface IPropertyUI : IUnknown {
public extern(Windows):
	HRESULT ParsePropertyName(LPCWSTR pszName, FMTID* pfmtid, PROPID* ppid, ULONG* pchEaten);
	HRESULT GetCannonicalName( REFFMTID fmtid, PROPID pid, LPWSTR pwszText, DWORD cchText);
	HRESULT GetDisplayName(REFFMTID fmtid, PROPID pid, PROPERTYUI_NAME_FLAGS flags, LPWSTR pwszText, DWORD cchText);
	HRESULT GetPropertyDescription(REFFMTID fmtid, PROPID pid, LPWSTR pwszText, DWORD cchText);
	HRESULT GetDefaultWidth(REFFMTID fmtid, PROPID pid, ULONG* pcxChars);
	HRESULT GetFlags(REFFMTID fmtid, PROPID pid, PROPERTYUI_FLAGS* pflags);
	HRESULT FormatForDisplay(REFFMTID fmtid, PROPID pid, const(PROPVARIANT)* ppropvar, PROPERTYUI_FORMAT_FLAGS puiff, LPWSTR pwszText, DWORD cchText);
	HRESULT GetHelpInfo(REFFMTID fmtid, PROPID pid, LPWSTR pwszHelpFile, DWORD cch, UINT* puHelpID);
}
mixin DEFINE_IID!(IPropertyUI, "757a7d9f-919a-4118-99d7-dbb208c8cc66");

static if(_WIN32_IE >= _WIN32_IE_IE70){
	export extern(Windows){
		HRESULT SHRemovePersonalPropertyValues(IShellItemArray psia);
		HRESULT SHAddDefaultPropertiesByExt(PCWSTR pszExt, IPropertyStore pPropStore);
		HRESULT SHCreateDefaultPropertiesOp(IShellItem psi, IFileOperation* ppFileOp);
		HRESULT SHSetDefaultProperties(HWND hwnd, IShellItem psi, DWORD dwFileOpFlags, IFileOperationProgressSink pfops);
	}
}

//extern extern(C) const IID IID_ICategoryProvider;
interface ICategoryProvider : IUnknown {
public extern(Windows):
	HRESULT CanCategorizeOnSCID(const(SHCOLUMNID)* pscid);
	HRESULT GetDefaultCategory(GUID* pguid, SHCOLUMNID* pscid);
	HRESULT GetCategoryForSCID(const(SHCOLUMNID)* pscid, GUID* pguid);
	HRESULT EnumCategories(IEnumGUID* penum);
	HRESULT GetCategoryName(const(GUID)* pguid, LPWSTR pszName, UINT cch);
	HRESULT CreateCategory(const(GUID)* pguid, REFIID riid, void** ppv);
}
mixin DEFINE_IID!(ICategoryProvider, "9af64809-5864-4c26-a720-c1f78c086ee3");

enum {
	CATINFO_NORMAL         = 0,
	CATINFO_COLLAPSED      = 0x1,
	CATINFO_HIDDEN         = 0x2,
	CATINFO_EXPANDED       = 0x4,
	CATINFO_NOHEADER       = 0x8,
	CATINFO_NOTCOLLAPSIBLE = 0x10,
	CATINFO_NOHEADERCOUNT  = 0x20,
	CATINFO_SUBSETTED      = 0x40
}
alias int CATEGORYINFO_FLAGS;

enum {
	CATSORT_DEFAULT = 0,
	CATSORT_NAME    = 0x1
}
alias int CATSORT_FLAGS;

struct CATEGORY_INFO {
	CATEGORYINFO_FLAGS cif;
	WCHAR[260] wszName;
}

//extern extern(C) const IID IID_ICategorizer;
interface ICategorizer : IUnknown {
public extern(Windows):
	HRESULT GetDescription(LPWSTR pszDesc, UINT cch);
	HRESULT GetCategory(UINT cidl, PCUITEMID_CHILD_ARRAY apidl, DWORD* rgCategoryIds);
	HRESULT GetCategoryInfo(DWORD dwCategoryId, CATEGORY_INFO* pci);
	HRESULT CompareCategory(CATSORT_FLAGS csfFlags, DWORD dwCategoryId1, DWORD dwCategoryId2);
}
mixin DEFINE_IID!(ICategorizer, "a3b14589-9174-49a8-89a3-06a1ae2b9ba7");

align(8)
struct SHDRAGIMAGE {
	SIZE sizeDragImage;
	POINT ptOffset;
	HBITMAP hbmpDragImage;
	COLORREF crColorKey;
}
alias SHDRAGIMAGE* LPSHDRAGIMAGE;

const wchar* DI_GETDRAGIMAGE = "ShellGetDragImage";

//extern extern(C) const IID IID_IDropTargetHelper;
interface IDropTargetHelper : IUnknown {
public extern(Windows):
	HRESULT DragEnter(HWND hwndTarget, IDataObject pDataObject, POINT* ppt, DWORD dwEffect);
	HRESULT DragLeave();
	HRESULT DragOver(POINT* ppt, DWORD dwEffect);
	HRESULT Drop(IDataObject pDataObject, POINT* ppt, DWORD dwEffect);
	HRESULT Show(BOOL fShow);
}
mixin DEFINE_IID!(IDropTargetHelper, "4657278B-411B-11D2-839A-00C04FD918D0");

//extern extern(C) const IID IID_IDragSourceHelper;
interface IDragSourceHelper : IUnknown {
public extern(Windows):
	HRESULT InitializeFromBitmap(LPSHDRAGIMAGE pshdi, IDataObject pDataObject);
	HRESULT InitializeFromWindow(HWND hwnd, POINT ppt, IDataObject pDataObject);
}
mixin DEFINE_GUID!(IDragSourceHelper, "DE5BF786-477A-11D2-839D-00C04FD918D0");

//(NTDDI_VERSION >= NTDDI_VISTA)
	enum {
		DSH_ALLOWDROPDESCRIPTIONTEXT = 0x1
	}
	alias int DSH_FLAGS;

	//extern extern(C) const IID IID_IDragSourceHelper2;
	interface IDragSourceHelper2 : IDragSourceHelper {
	public extern(Windows):
		HRESULT SetFlags(DWORD dwFlags);
	}
	mixin DEFINE_IID!(IDragSourceHelper2, "83E07D0D-0C5F-4163-BF1A-60B274051E40");

enum {
	SLR_NO_UI                     = 0x1,
	SLR_ANY_MATCH                 = 0x2,
	SLR_UPDATE                    = 0x4,
	SLR_NOUPDATE                  = 0x8,
	SLR_NOSEARCH                  = 0x10,
	SLR_NOTRACK                   = 0x20,
	SLR_NOLINKINFO                = 0x40,
	SLR_INVOKE_MSI                = 0x80,
	SLR_NO_UI_WITH_MSG_PUMP       = 0x101,
	SLR_OFFER_DELETE_WITHOUT_FILE = 0x200,
	SLR_KNOWNFOLDER               = 0x400,
	SLR_MACHINE_IN_LOCAL_TARGET   = 0x800,
	SLR_UPDATE_MACHINE_AND_SID    = 0x1000
}
alias int SLR_FLAGS;

enum {
	SLGP_SHORTPATH        = 0x1,
	SLGP_UNCPRIORITY      = 0x2,
	SLGP_RAWPATH          = 0x4,
	SLGP_RELATIVEPRIORITY = 0x8
}
alias int SLGP_FLAGS;

//extern extern(C) const IID IID_IShellLinkA;
interface IShellLinkA : IUnknown {
public extern(Windows):
	HRESULT GetPath(LPSTR pszFile, int cch, WIN32_FIND_DATAA* pfd, DWORD fFlags);
	HRESULT GetIDList(PIDLIST_ABSOLUTE* ppidl);
	HRESULT SetIDList(PCIDLIST_ABSOLUTE pidl);
	HRESULT GetDescription(LPSTR pszName, int cch);
	HRESULT SetDescription(LPCSTR pszName);
	HRESULT GetWorkingDirectory(LPSTR pszDir, int cch);
	HRESULT SetWorkingDirectory(LPCSTR pszDir);
	HRESULT GetArguments(LPSTR pszArgs, int cch);
	HRESULT SetArguments(LPCSTR pszArgs);
	HRESULT GetHotkey(WORD* pwHotkey);
	HRESULT SetHotkey(WORD wHotkey);
	HRESULT GetShowCmd(int* piShowCmd);
	HRESULT SetShowCmd(int iShowCmd);
	HRESULT GetIconLocation(LPSTR pszIconPath, int cch, int* piIcon);
	HRESULT SetIconLocation(LPCSTR pszIconPath, int iIcon);
	HRESULT SetRelativePath(LPCSTR pszPathRel, DWORD dwReserved);
	HRESULT Resolve(HWND hwnd, DWORD fFlags);
	HRESULT SetPath(LPCSTR pszFile);
}
mixin DEFINE_IID!(IShellLinkA, "000214EE-0000-0000-C000-000000000046");

//extern extern(C) const IID IID_IShellLinkW;
interface IShellLinkW : IUnknown {
public extern(Windows):
	HRESULT GetPath(LPWSTR pszFile, int cch, WIN32_FIND_DATAW* pfd, DWORD fFlags);
	HRESULT GetIDList(PIDLIST_ABSOLUTE* ppidl);
	HRESULT SetIDList(PCIDLIST_ABSOLUTE pidl);
	HRESULT GetDescription(LPWSTR pszName, int cch);
	HRESULT SetDescription(LPCWSTR pszName);
	HRESULT GetWorkingDirectory(LPWSTR pszDir, int cch);
	HRESULT SetWorkingDirectory(LPCWSTR pszDir);
	HRESULT GetArguments(LPWSTR pszArgs, int cch);
	HRESULT SetArguments(LPCWSTR pszArgs);
	HRESULT GetHotkey(WORD* pwHotkey);
	HRESULT SetHotkey(WORD wHotkey);
	HRESULT GetShowCmd(int* piShowCmd);
	HRESULT SetShowCmd(int iShowCmd);
	HRESULT GetIconLocation(LPWSTR pszIconPath, int cch, int* piIcon);
	HRESULT SetIconLocation(LPCWSTR pszIconPath, int iIcon);
	HRESULT SetRelativePath(LPCWSTR pszPathRel, DWORD dwReserved);
	HRESULT Resolve(HWND hwnd, DWORD fFlags);
	HRESULT SetPath(LPCWSTR pszFile);
}
mixin DEFINE_IID!(IShellLinkW, "000214F9-0000-0000-C000-000000000046");

version(UNICODE)
	alias IShellLinkW IShellLink;
else
	alias IShellLinkA IShellLink;

//extern extern(C) const IID IID_IShellLinkDataList;
interface IShellLinkDataList : IUnknown {
public extern(Windows):
	HRESULT AddDataBlock(void* pDataBlock);
	HRESULT CopyDataBlock(DWORD dwSig, void** ppDataBlock);
	HRESULT RemoveDataBlock(DWORD dwSig);
	HRESULT GetFlags(DWORD* pdwFlags);
	HRESULT SetFlags(DWORD dwFlags);
}
mixin DEFINE_IID!(IShellLinkDataList, "45e2b4ae-b1c3-11d0-b92f-00a0c90312e1");

//extern extern(C) const IID IID_IResolveShellLink;
interface IResolveShellLink : IUnknown {
public extern(Windows):
	HRESULT ResolveShellLink(IUnknown punkLink, HWND hwnd, DWORD fFlags);
}
mixin DEFINE_IID!(IResolveShellLink, "5cd52983-9449-11d2-963a-00c04f79adf0");

enum {
	SPINITF_NORMAL     = 0,
	SPINITF_MODAL      = 0x1,
	SPINITF_NOMINIMIZE = 0x8
}
alias DWORD SPINITF;

//extern extern(C) const IID IID_IActionProgressDialog;
interface IActionProgressDialog : IUnknown {
public extern(Windows):
	HRESULT Initialize(SPINITF flags, LPCWSTR pszTitle, LPCWSTR pszCancel);
	HRESULT Stop();
}
mixin DEFINE_IID!(IActionProgressDialog, "49ff1172-eadc-446d-9285-156453a6431c");

//extern extern(C) const IID IID_IHWEventHandler;
interface IHWEventHandler : IUnknown {
public extern(Windows):
	HRESULT Initialize(LPCWSTR pszParams);
	HRESULT HandleEvent(LPCWSTR pszDeviceID, LPCWSTR pszAltDeviceID, LPCWSTR pszEventType);
	HRESULT HandleEventWithContent(LPCWSTR pszDeviceID, LPCWSTR pszAltDeviceID, LPCWSTR pszEventType, LPCWSTR pszContentTypeHandler, IDataObject pdataobject);
}
mixin DEFINE_IID!(IHWEventHandler, "C1FB73D0-EC3A-4ba2-B512-8CDB9187B6D1");

//extern extern(C) const IID IID_IHWEventHandler2;
interface IHWEventHandler2 : IHWEventHandler {
public extern(Windows):
	HRESULT HandleEventWithHWND(LPCWSTR pszDeviceID, LPCWSTR pszAltDeviceID, LPCWSTR pszEventType, HWND hwndOwner);
}
mixin DEFINE_IID!(IHWEventHandler2, "CFCC809F-295D-42e8-9FFC-424B33C487E6");

enum {
	ARCONTENT_AUTORUNINF     = 0x00000002,
	ARCONTENT_AUDIOCD        = 0x00000004,
	ARCONTENT_DVDMOVIE       = 0x00000008,
	ARCONTENT_BLANKCD        = 0x00000010,
	ARCONTENT_BLANKDVD       = 0x00000020,
	ARCONTENT_UNKNOWNCONTENT = 0x00000040,
	ARCONTENT_AUTOPLAYPIX    = 0x00000080,
	ARCONTENT_AUTOPLAYMUSIC  = 0x00000100,
	ARCONTENT_AUTOPLAYVIDEO  = 0x00000200,
	//(NTDDI_VERSION >= NTDDI_VISTA)
		ARCONTENT_VCD            = 0x00000400,
		ARCONTENT_SVCD           = 0x00000800,
		ARCONTENT_DVDAUDIO       = 0x00001000,
		ARCONTENT_BLANKBD        = 0x00002000,
		ARCONTENT_BLURAY         = 0x00004000,
		ARCONTENT_NONE           = 0x00000000,
		ARCONTENT_MASK           = 0x00007FFE,
		ARCONTENT_PHASE_UNKNOWN  = 0x00000000,
		ARCONTENT_PHASE_PRESNIFF = 0x10000000,
		ARCONTENT_PHASE_SNIFFING = 0x20000000,
		ARCONTENT_PHASE_FINAL    = 0x40000000,
		ARCONTENT_PHASE_MASK     = 0x70000000,
}

//extern extern(C) const IID IID_IQueryCancelAutoPlay;
interface IQueryCancelAutoPlay : IUnknown {
public extern(Windows):
	HRESULT AllowAutoPlay(LPCWSTR pszPath, DWORD dwContentType, LPCWSTR pszLabel, DWORD dwSerialNumber);
}
mixin DEFINE_IID!(IQueryCancelAutoPlay, "DDEFE873-6997-4e68-BE26-39B633ADBE12");

//extern extern(C) const IID IID_IDynamicHWHandler;
interface IDynamicHWHandler : IUnknown {
public extern(Windows):
	HRESULT GetDynamicInfo(LPCWSTR pszDeviceID, DWORD dwContentType, LPWSTR* ppszAction);
}
mixin DEFINE_IID!(IDynamicHWHandler, "DC2601D7-059E-42fc-A09D-2AFD21B6D5F7");

enum {
	SPBEGINF_NORMAL          = 0,
	SPBEGINF_AUTOTIME        = 0x2,
	SPBEGINF_NOPROGRESSBAR   = 0x10,
	SPBEGINF_MARQUEEPROGRESS = 0x20,
	SPBEGINF_NOCANCELBUTTON  = 0x40
}
alias DWORD SPBEGINF;

enum {
	SPACTION_NONE,
	SPACTION_MOVING,
	SPACTION_COPYING,
	SPACTION_RECYCLING,
	SPACTION_APPLYINGATTRIBS,
	SPACTION_DOWNLOADING,
	SPACTION_SEARCHING_INTERNET,
	SPACTION_CALCULATING,
	SPACTION_UPLOADING,
	SPACTION_SEARCHING_FILES,
	SPACTION_DELETING,
	SPACTION_RENAMING,
	SPACTION_FORMATTING,
	SPACTION_COPY_MOVING,
}
alias int SPACTION;

enum {
	SPTEXT_ACTIONDESCRIPTION = 1,
	SPTEXT_ACTIONDETAIL,
} 
alias int SPTEXT;

//extern extern(C) const IID IID_IActionProgress;
interface IActionProgress : IUnknown {
public extern(Windows):
	HRESULT Begin(SPACTION action, SPBEGINF flags);
	HRESULT UpdateProgress(ULONGLONG ulCompleted, ULONGLONG ulTotal);
	HRESULT UpdateText(SPTEXT sptext, LPCWSTR pszText, BOOL fMayCompact);
	HRESULT QueryCancel(BOOL* pfCancelled);
	HRESULT ResetCancel();
	HRESULT End();
}
mixin DEFINE_IID!(IActionProgress, "49ff1173-eadc-446d-9285-156453a6431c");

//extern extern(C) const IID IID_IShellExtInit;
interface IShellExtInit : IUnknown {
public extern(Windows):
	HRESULT Initialize(PCIDLIST_ABSOLUTE pidlFolder, IDataObject pdtobj, HKEY hkeyProgID);
}
mixin DEFINE_IID!(IShellExtInit, "000214E8-0000-0000-C000-000000000046");
alias IShellExtInit LPSHELLEXTINIT;

enum {
	EXPPS_FILETYPES = 0x1
}
alias UINT EXPPS;

//extern extern(C) const IID IID_IShellPropSheetExt;
interface IShellPropSheetExt : IUnknown {
public extern(Windows):
	HRESULT AddPages(LPFNSVADDPROPSHEETPAGE pfnAddPage, LPARAM lParam);
	HRESULT ReplacePage(EXPPS uPageID, LPFNSVADDPROPSHEETPAGE pfnReplaceWith, LPARAM lParam);
}
mixin DEFINE_IID!(IShellPropSheetExt, "000214E9-0000-0000-C000-000000000046");
alias IShellPropSheetExt LPSHELLPROPSHEETEXT;

//extern extern(C) const IID IID_IRemoteComputer;
interface IRemoteComputer : IUnknown {
public extern(Windows):
	HRESULT Initialize(LPCWSTR pszMachine, BOOL bEnumerating);
}
mixin DEFINE_IID!(IRemoteComputer, "000214FE-0000-0000-C000-000000000046");

//extern extern(C) const IID IID_IQueryContinue;
interface IQueryContinue : IUnknown {
public extern(Windows):
	HRESULT QueryContinue();
}
mixin DEFINE_IID!(IQueryContinue, "7307055c-b24a-486b-9f25-163e597a28a9");

//extern extern(C) const IID IID_IObjectWithCancelEvent;
interface IObjectWithCancelEvent : IUnknown {
public extern(Windows):
	HRESULT GetCancelEvent(HANDLE* phEvent);
}
mixin DEFINE_IID!(IObjectWithCancelEvent, "F279B885-0AE9-4b85-AC06-DDECF9408941");

//extern extern(C) const IID IID_IUserNotification;
interface IUserNotification : IUnknown {
public extern(Windows):
	HRESULT SetBalloonInfo(LPCWSTR pszTitle, LPCWSTR pszText, DWORD dwInfoFlags);
	HRESULT SetBalloonRetry(DWORD dwShowTime, DWORD dwInterval, UINT cRetryCount);
	HRESULT SetIconInfo(HICON hIcon, LPCWSTR pszToolTip);
	HRESULT Show(IQueryContinue pqc, DWORD dwContinuePollInterval);
	HRESULT PlaySound(LPCWSTR pszSoundName);
}
mixin DEFINE_IID!(IUserNotification, "ba9711ba-5893-4787-a7e1-41277151550b");

//extern extern(C) const IID IID_IUserNotificationCallback;
interface IUserNotificationCallback : IUnknown {
public extern(Windows):
	HRESULT OnBalloonUserClick(POINT* pt);
	HRESULT OnLeftClick(POINT* pt);
	HRESULT OnContextMenu(POINT* pt);
}
mixin DEFINE_IID!(IUserNotificationCallback, "19108294-0441-4AFF-8013-FA0A730B0BEA");

//extern extern(C) const IID IID_IUserNotification2;
interface IUserNotification2 : IUnknown {
public extern(Windows):
	HRESULT SetBalloonInfo(LPCWSTR pszTitle, LPCWSTR pszText, DWORD dwInfoFlags);
	HRESULT SetBalloonRetry(DWORD dwShowTime, DWORD dwInterval, UINT cRetryCount);
	HRESULT SetIconInfo(HICON hIcon, LPCWSTR pszToolTip);
	HRESULT Show(IQueryContinue pqc, DWORD dwContinuePollInterval, IUserNotificationCallback pSink);
	HRESULT PlaySound(LPCWSTR pszSoundName);
}
mixin DEFINE_IID!(IUserNotification2, "215913CC-57EB-4FAB-AB5A-E5FA7BEA2A6C");

//extern extern(C) const IID IID_IItemNameLimits;
interface IItemNameLimits : IUnknown {
public extern(Windows):
	HRESULT GetValidCharacters(LPWSTR* ppwszValidChars, LPWSTR* ppwszInvalidChars);
	HRESULT GetMaxLength(LPCWSTR pszName, int* piMaxNameLen);
}
mixin DEFINE_IID!(IItemNameLimits, "1df0d7f1-b267-4d28-8b10-12e23202a5c4");

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_ISearchFolderItemFactory;
	interface ISearchFolderItemFactory : IUnknown {
	public extern(Windows):
		HRESULT SetDisplayName(LPCWSTR pszDisplayName);
		HRESULT SetFolderTypeID(FOLDERTYPEID ftid);
		HRESULT SetFolderLogicalViewMode(FOLDERLOGICALVIEWMODE flvm);
		HRESULT SetIconSize(int iIconSize);
		HRESULT SetVisibleColumns(UINT cVisibleColumns, PROPERTYKEY* rgKey);
		HRESULT SetSortColumns(UINT cSortColumns, SORTCOLUMN* rgSortColumns);
		HRESULT SetGroupColumn(REFPROPERTYKEY keyGroup);
		HRESULT SetStacks(UINT cStackKeys, PROPERTYKEY* rgStackKeys);
		HRESULT SetScope(IShellItemArray psiaScope);
		HRESULT SetCondition(ICondition pCondition);
		HRESULT GetShellItem(REFIID riid, void** ppv);
		HRESULT GetIDList(PIDLIST_ABSOLUTE* ppidl);
	}
	mixin DEFINE_IID!(ISearchFolderItemFactory, "a0ffbc28-5482-4366-be27-3e81e78e06c2");

enum {
	IEI_PRIORITY_MAX     = ITSAT_MAX_PRIORITY,
	IEI_PRIORITY_MIN     = ITSAT_MIN_PRIORITY,
	IEIT_PRIORITY_NORMAL = ITSAT_DEFAULT_PRIORITY,
	IEIFLAG_ASYNC        = 0x0001,
	IEIFLAG_CACHE        = 0x0002,
	IEIFLAG_ASPECT       = 0x0004,
	IEIFLAG_OFFLINE      = 0x0008,
	IEIFLAG_GLEAM        = 0x0010,
	IEIFLAG_SCREEN       = 0x0020,
	IEIFLAG_ORIGSIZE     = 0x0040,
	IEIFLAG_NOSTAMP      = 0x0080,
	IEIFLAG_NOBORDER     = 0x0100,
	IEIFLAG_QUALITY      = 0x0200,
	IEIFLAG_REFRESH      = 0x0400,
}

//extern extern(C) const IID IID_IExtractImage;
interface IExtractImage : IUnknown {
public extern(Windows):
	HRESULT GetLocation(LPWSTR pszPathBuffer, DWORD cch, DWORD* pdwPriority, const(SIZE)* prgSize, DWORD dwRecClrDepth, DWORD* pdwFlags);
	HRESULT Extract(HBITMAP* phBmpThumbnail);
}
mixin DEFINE_IID!(IExtractImage, "BB2E617C-0920-11d1-9A0B-00C04FC2D6C1");
alias IExtractImage LPEXTRACTIMAGE;

//extern extern(C) const IID IID_IExtractImage2;
interface IExtractImage2 : IExtractImage {
public extern(Windows):
	HRESULT GetDateStamp(FILETIME* pDateStamp);
}
mixin DEFINE_IID!(IExtractImage2, "953BB1EE-93B4-11d1-98A3-00C04FB687DA");
alias IExtractImage2 LPEXTRACTIMAGE2;

//extern extern(C) const IID IID_IThumbnailHandlerFactory;
interface IThumbnailHandlerFactory : IUnknown {
public extern(Windows):
	HRESULT GetThumbnailHandler(PCUITEMID_CHILD pidlChild, IBindCtx pbc, REFIID riid, void** ppv);
}
mixin DEFINE_IID!(IThumbnailHandlerFactory, "e35b4b2e-00da-4bc1-9f13-38bc11f5d417");

//extern extern(C) const IID IID_IParentAndItem;
interface IParentAndItem : IUnknown {
public extern(Windows):
	HRESULT SetParentAndItem(PCIDLIST_ABSOLUTE pidlParent, IShellFolder psf, PCUITEMID_CHILD pidlChild);
	HRESULT GetParentAndItem(PIDLIST_ABSOLUTE* ppidlParent, IShellFolder* ppsf, PITEMID_CHILD* ppidlChild);
}
mixin DEFINE_IID!(IParentAndItem, "b3a4b685-b685-4805-99d9-5dead2873236");

export extern(Windows){
	HRESULT IParentAndItem_RemoteGetParentAndItem_Proxy(IParentAndItem This, PIDLIST_ABSOLUTE* ppidlParent, IShellFolder* ppsf, PITEMID_CHILD* ppidlChild);
	void IParentAndItem_RemoteGetParentAndItem_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
}

//extern extern(C) const IID IID_IDockingWindow;
interface IDockingWindow : IOleWindow {
public extern(Windows):
	HRESULT ShowDW(BOOL fShow);
	HRESULT CloseDW(DWORD dwReserved);
	HRESULT ResizeBorderDW(LPCRECT prcBorder, IUnknown punkToolbarSite, BOOL fReserved);
}
mixin DEFINE_IID!(IDockingWindow, "012dd920-7b26-11d0-8ca9-00a0c92dbfe8");

enum {
	DBIM_MINSIZE   = 0x0001,
	DBIM_MAXSIZE   = 0x0002,
	DBIM_INTEGRAL  = 0x0004,
	DBIM_ACTUAL    = 0x0008,
	DBIM_TITLE     = 0x0010,
	DBIM_MODEFLAGS = 0x0020,
	DBIM_BKCOLOR   = 0x0040,
}

align(8)
struct DESKBANDINFO {
	DWORD dwMask;
	POINTL ptMinSize;
	POINTL ptMaxSize;
	POINTL ptIntegral;
	POINTL ptActual;
	WCHAR[256] wszTitle;
	DWORD dwModeFlags;
	COLORREF crBkgnd;
}

enum {
	DBIMF_NORMAL         = 0x0000,
	DBIMF_FIXED          = 0x0001,
	DBIMF_FIXEDBMP       = 0x0004,
	DBIMF_VARIABLEHEIGHT = 0x0008,
	DBIMF_UNDELETEABLE   = 0x0010,
	DBIMF_DEBOSSED       = 0x0020,
	DBIMF_BKCOLOR        = 0x0040,
	DBIMF_USECHEVRON     = 0x0080,
	DBIMF_BREAK          = 0x0100,
	DBIMF_ADDTOFRONT     = 0x0200,
	DBIMF_TOPALIGN       = 0x0400,
	//(NTDDI_VERSION >= NTDDI_VISTA)
		DBIMF_NOGRIPPER     = 0x0800,
		DBIMF_ALWAYSGRIPPER = 0x1000,
		DBIMF_NOMARGINS     = 0x2000,
	DBIF_VIEWMODE_NORMAL      = 0x0000,
	DBIF_VIEWMODE_VERTICAL    = 0x0001,
	DBIF_VIEWMODE_FLOATING    = 0x0002,
	DBIF_VIEWMODE_TRANSPARENT = 0x0004,
}

enum {
	DBID_BANDINFOCHANGED = 0,
	DBID_SHOWONLY        = 1,
	DBID_MAXIMIZEBAND    = 2,
	DBID_PUSHCHEVRON     = 3,
	DBID_DELAYINIT       = 4,
	DBID_FINISHINIT      = 5,
	DBID_SETWINDOWTHEME  = 6,
	DBID_PERMITAUTOHIDE  = 7
}
alias int DESKBANDCID;
enum DBPC_SELECTFIRST = cast(DWORD)-1;
enum DBPC_SELECTLAST = cast(DWORD)-2;

//extern extern(C) const IID IID_IDeskBand;
interface IDeskBand : IDockingWindow {
public extern(Windows):
	HRESULT GetBandInfo(DWORD dwBandID, DWORD dwViewMode, DESKBANDINFO* pdbi);
}
mixin DEFINE_IID!(IDeskBand, "EB0FE172-1A3A-11D0-89B3-00A0C90A90AC");
alias IID_IDeskBand CGID_DeskBand;

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_IDeskBandInfo;
	interface IDeskBandInfo : IUnknown {
	public extern(Windows):
		HRESULT GetDefaultBandWidth(DWORD dwBandID, DWORD dwViewMode, int* pnWidth);
	}
	mixin DEFINE_IID!(IDeskBandInfo, "77E425FC-CBF9-4307-BA6A-BB5727745661");

	//extern extern(C) const IID IID_IDeskBand2;
	interface IDeskBand2 : IDeskBand {
	public extern(Windows):
		HRESULT CanRenderComposited(BOOL* pfCanRenderComposited);
		HRESULT SetCompositionState(BOOL fCompositionEnabled);
		HRESULT GetCompositionState(BOOL* pfCompositionEnabled);
	}
	mixin DEFINE_IID!(IDeskBand2, "79D16DE4-ABEE-4021-8D9D-9169B261D657");

//extern extern(C) const IID IID_ITaskbarList;
interface ITaskbarList : IUnknown {
public extern(Windows):
	HRESULT HrInit();
	HRESULT AddTab(HWND hwnd);
	HRESULT DeleteTab(HWND hwnd);
	HRESULT ActivateTab(HWND hwnd);
	HRESULT SetActiveAlt(HWND hwnd);
}
mixin DEFINE_IID!(ITaskbarList, "56FDF342-FD6D-11d0-958A-006097C9A090");

//extern extern(C) const IID IID_ITaskbarList2;
interface ITaskbarList2 : ITaskbarList {
public extern(Windows):
	HRESULT MarkFullscreenWindow(HWND hwnd, BOOL fFullscreen);
}
mixin DEFINE_IID!(ITaskbarList2, "602D4995-B13A-429b-A66E-1935E44F4317");

enum {
	THBF_ENABLED        = 0,
	THBF_DISABLED       = 0x1,
	THBF_DISMISSONCLICK = 0x2,
	THBF_NOBACKGROUND   = 0x4,
	THBF_HIDDEN         = 0x8,
	THBF_NONINTERACTIVE = 0x10
}
alias int THUMBBUTTONFLAGS;

enum {
	THB_BITMAP  = 0x1,
	THB_ICON    = 0x2,
	THB_TOOLTIP = 0x4,
	THB_FLAGS   = 0x8
}
alias int THUMBBUTTONMASK;

align(8)
struct THUMBBUTTON {
	THUMBBUTTONMASK dwMask;
	UINT iId;
	UINT iBitmap;
	HICON hIcon;
	WCHAR[260] szTip;
	THUMBBUTTONFLAGS dwFlags;
}
alias THUMBBUTTON* LPTHUMBBUTTON;

enum THBN_CLICKED = 0x1800;

enum {
	TBPF_NOPROGRESS    = 0,
	TBPF_INDETERMINATE = 0x1,
	TBPF_NORMAL        = 0x2,
	TBPF_ERROR         = 0x4,
	TBPF_PAUSED        = 0x8
}
alias int TBPFLAG;

//extern extern(C) const IID IID_ITaskbarList3;
interface ITaskbarList3 : ITaskbarList2 {
public extern(Windows):
	HRESULT SetProgressValue(HWND hwnd, ULONGLONG ullCompleted, ULONGLONG ullTotal);
	HRESULT SetProgressState(HWND hwnd, TBPFLAG tbpFlags);
	HRESULT RegisterTab(HWND hwndTab, HWND hwndMDI);
	HRESULT UnregisterTab(HWND hwndTab);
	HRESULT SetTabOrder(HWND hwndTab, HWND hwndInsertBefore);
	HRESULT SetTabActive(HWND hwndTab, HWND hwndMDI, DWORD dwReserved);
	HRESULT ThumbBarAddButtons(HWND hwnd, UINT cButtons, LPTHUMBBUTTON pButton);
	HRESULT ThumbBarUpdateButtons(HWND hwnd, UINT cButtons, LPTHUMBBUTTON pButton);
	HRESULT ThumbBarSetImageList(HWND hwnd, HIMAGELIST himl);
	HRESULT SetOverlayIcon(HWND hwnd, HICON hIcon, LPCWSTR pszDescription);
	HRESULT SetThumbnailTooltip(HWND hwnd, LPCWSTR pszTip);
	HRESULT SetThumbnailClip(HWND hwnd, RECT* prcClip);
}
mixin DEFINE_IID!(ITaskbarList3, "ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf");

enum {
	STPF_NONE                      = 0,
	STPF_USEAPPTHUMBNAILALWAYS     = 0x1,
	STPF_USEAPPTHUMBNAILWHENACTIVE = 0x2,
	STPF_USEAPPPEEKALWAYS          = 0x4,
	STPF_USEAPPPEEKWHENACTIVE      = 0x8
}
alias int STPFLAG;

//extern extern(C) const IID IID_ITaskbarList4;
interface ITaskbarList4 : ITaskbarList3 {
public extern(Windows):
	HRESULT SetTabProperties(HWND hwndTab, STPFLAG stpFlags);
}
mixin DEFINE_IID!(ITaskbarList4, "c43dc798-95d1-4bea-9030-bb99e2983a1a");

//extern extern(C) const IID IID_IStartMenuPinnedList;
interface IStartMenuPinnedList : IUnknown {
public extern(Windows):
	HRESULT RemoveFromList(IShellItem pitem);
}
mixin DEFINE_IID!(IStartMenuPinnedList, "4CD19ADA-25A5-4A32-B3B7-347BEE5BE36B");

//extern extern(C) const IID IID_ICDBurn;
interface ICDBurn : IUnknown {
public extern(Windows):
	HRESULT GetRecorderDriveLetter(LPWSTR pszDrive, UINT cch);
	HRESULT Burn(HWND hwnd);
	HRESULT HasRecordableDrive(BOOL* pfHasRecorder);
}
mixin DEFINE_IID!(ICDBurn, "3d73a659-e5d0-4d42-afc0-5121ba425c8d");

enum {
	IDD_WIZEXTN_FIRST = 0x5000,
	IDD_WIZEXTN_LAST  = 0x5100,
}

//extern extern(C) const IID IID_IWizardSite;
interface IWizardSite : IUnknown {
public extern(Windows):
	HRESULT GetPreviousPage(HPROPSHEETPAGE* phpage);
	HRESULT GetNextPage(HPROPSHEETPAGE* phpage);
	HRESULT GetCancelledPage(HPROPSHEETPAGE* phpage);
}
mixin DEFINE_IID!(IWizardSite, "88960f5b-422f-4e7b-8013-73415381c3c3");
alias IID_IWizardSite SID_WizardSite;

//extern extern(C) const IID IID_IWizardExtension;
interface IWizardExtension : IUnknown {
public extern(Windows):
	HRESULT AddPages(HPROPSHEETPAGE* aPages, UINT cPages, UINT* pnPagesAdded);
	HRESULT GetFirstPage(HPROPSHEETPAGE* phpage);
	HRESULT GetLastPage(HPROPSHEETPAGE* phpage);
}
mixin DEFINE_IID!(IWizardExtension, "c02ea696-86cc-491e-9b23-74394a0444a8");

//extern extern(C) const IID IID_IWebWizardExtension;
interface IWebWizardExtension : IWizardExtension {
public extern(Windows):
	HRESULT SetInitialURL(LPCWSTR pszURL);
	HRESULT SetErrorURL(LPCWSTR pszErrorURL);
}
mixin DEFINE_IID!(IWebWizardExtension, "0e6b3f66-98d1-48c0-a222-fbde74e2fbc5");
alias IID_IWebWizardExtension SID_WebWizardHost;

enum {
	SHPWHF_NORECOMPRESS     = 0x00000001,
	SHPWHF_NONETPLACECREATE = 0x00000002,
	SHPWHF_NOFILESELECTOR   = 0x00000004,
	SHPWHF_USEMRU           = 0x00000008,
	//(NTDDI_VERSION >= NTDDI_VISTA)
		SHPWHF_ANYLOCATION = 0x00000100,
	SHPWHF_VALIDATEVIAWEBFOLDERS = 0x00010000,
}

//extern extern(C) const IID IID_IPublishingWizard;
interface IPublishingWizard : IWizardExtension {
public extern(Windows):
	HRESULT Initialize(IDataObject pdo, DWORD dwOptions, LPCWSTR pszServiceScope);
	HRESULT GetTransferManifest(HRESULT* phrFromTransfer, IXMLDOMDocument* pdocManifest);
}
mixin DEFINE_IID!(IPublishingWizard, "aa9198bb-ccec-472d-beed-19a4f6733f7a");

//(NTDDI_VERSION >= NTDDI_WINXP) || (_WIN32_IE >= _WIN32_IE_IE70)
	//extern extern(C) const IID IID_IFolderViewHost;
	interface IFolderViewHost : IUnknown {
	public extern(Windows):
		HRESULT Initialize(HWND hwndParent, IDataObject pdo, RECT* prc);
	}
	mixin DEFINE_IID!(IFolderViewHost, "1ea58f02-d55a-411d-b09e-9e65ac21605b");

	//(_WIN32_IE >= _WIN32_IE_IE70)
		//extern extern(C) const IID IID_IExplorerBrowserEvents;
		interface IExplorerBrowserEvents : IUnknown {
		public extern(Windows):
			HRESULT OnNavigationPending(PCIDLIST_ABSOLUTE pidlFolder);
			HRESULT OnViewCreated(IShellView psv);
			HRESULT OnNavigationComplete(PCIDLIST_ABSOLUTE pidlFolder);
			HRESULT OnNavigationFailed(PCIDLIST_ABSOLUTE pidlFolder);
		}
		mixin DEFINE_IID!(IExplorerBrowserEvents, "361bbdc7-e6ee-4e13-be58-58e2240c810f");

	enum {
		EBO_NONE               = 0,
		EBO_NAVIGATEONCE       = 0x1,
		EBO_SHOWFRAMES         = 0x2,
		EBO_ALWAYSNAVIGATE     = 0x4,
		EBO_NOTRAVELLOG        = 0x8,
		EBO_NOWRAPPERWINDOW    = 0x10,
		EBO_HTMLSHAREPOINTVIEW = 0x20
	}
	alias int EXPLORER_BROWSER_OPTIONS;

	enum {
		EBF_NONE                 = 0,
		EBF_SELECTFROMDATAOBJECT = 0x100,
		EBF_NODROPTARGET         = 0x200
	}
	alias int EXPLORER_BROWSER_FILL_FLAGS;

	//extern extern(C) const IID IID_IExplorerBrowser;
	interface IExplorerBrowser : IUnknown {
	public extern(Windows):
		HRESULT Initialize(HWND hwndParent, const(RECT)* prc, const(FOLDERSETTINGS)* pfs);
		HRESULT Destroy();
		HRESULT SetRect(HDWP* phdwp, RECT rcBrowser);
		HRESULT SetPropertyBag(LPCWSTR pszPropertyBag);
		HRESULT SetEmptyText(LPCWSTR pszEmptyText);
		HRESULT SetFolderSettings(const(FOLDERSETTINGS)* pfs);
		HRESULT Advise(IExplorerBrowserEvents psbe, DWORD* pdwCookie);
		HRESULT Unadvise(DWORD dwCookie);
		HRESULT SetOptions(EXPLORER_BROWSER_OPTIONS dwFlag);
		HRESULT GetOptions(EXPLORER_BROWSER_OPTIONS* pdwFlag);
		HRESULT BrowseToIDList(PCUIDLIST_RELATIVE pidl, UINT uFlags);
		HRESULT BrowseToObject(IUnknown punk, UINT uFlags);
		HRESULT FillFromObject(IUnknown punk, EXPLORER_BROWSER_FILL_FLAGS dwFlags);
		HRESULT RemoveAll();
		HRESULT GetCurrentView(REFIID riid, void** ppv);
	}
	mixin DEFINE_IID!(IExplorerBrowser, "dfd3b6b5-c10c-4be9-85f6-a66969f402f6");

	//extern extern(C) const IID IID_IAccessibleObject;
	interface IAccessibleObject : IUnknown {
	public extern(Windows):
		HRESULT SetAccessibleName(LPCWSTR pszName);
	}
	mixin DEFINE_IID!(IAccessibleObject, "95A391C5-9ED4-4c28-8401-AB9E06719E11");

	//extern extern(C) const IID IID_IResultsFolder;
	interface IResultsFolder : IUnknown {
	public extern(Windows):
		HRESULT AddItem(IShellItem psi);
		HRESULT AddIDList(PCIDLIST_ABSOLUTE pidl, PITEMID_CHILD* ppidlAdded);
		HRESULT RemoveItem(IShellItem psi);
		HRESULT RemoveIDList(PCIDLIST_ABSOLUTE pidl);
		HRESULT RemoveAll();
	}
	mixin DEFINE_IID!(IResultsFolder, "96E5AE6D-6AE1-4b1c-900C-C6480EAA8828");

static if((NTDDI_VERSION >= NTDDI_WINXP) || (_WIN32_IE >= _WIN32_IE_IE70)){
	export extern(Windows){
		HRESULT IResultsFolder_RemoteAddIDList_Proxy(IResultsFolder This, PCIDLIST_ABSOLUTE pidl, PITEMID_CHILD* ppidlAdded);
		void IResultsFolder_RemoteAddIDList_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}
}

	//(_WIN32_IE >= _WIN32_IE_IE70)
		//extern extern(C) const IID IID_IEnumObjects;
		interface IEnumObjects : IUnknown {
		public extern(Windows):
			HRESULT Next(ULONG celt, REFIID riid, void** rgelt, ULONG* pceltFetched);
			HRESULT Skip(ULONG celt);
			HRESULT Reset();
			HRESULT Clone(IEnumObjects* ppenum);
		}
		mixin DEFINE_IID!(IEnumObjects, "2c1c7e2e-2d0e-4059-831e-1e6f82335c2e");

static if(_WIN32_IE >= _WIN32_IE_IE70){
	export extern(Windows){
		HRESULT IEnumObjects_RemoteNext_Proxy(IEnumObjects This, ULONG celt, REFIID riid, void** rgelt, ULONG* pceltFetched);
		void IEnumObjects_RemoteNext_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}
}

	enum {
		OPPROGDLG_DEFAULT               = 0,
		OPPROGDLG_ENABLEPAUSE           = 0x80,
		OPPROGDLG_ALLOWUNDO             = 0x100,
		OPPROGDLG_DONTDISPLAYSOURCEPATH = 0x200,
		OPPROGDLG_DONTDISPLAYDESTPATH   = 0x400,
		OPPROGDLG_NOMULTIDAYESTIMATES   = 0x800,
		OPPROGDLG_DONTDISPLAYLOCATIONS  = 0x1000
	}
	alias DWORD OPPROGDLGF;

	enum {
		PDM_DEFAULT        = 0,
		PDM_RUN            = 0x1,
		PDM_PREFLIGHT      = 0x2,
		PDM_UNDOING        = 0x4,
		PDM_ERRORSBLOCKING = 0x8,
		PDM_INDETERMINATE  = 0x10
	}
	alias DWORD PDMODE;

	enum {
		PDOPS_RUNNING   = 1,
		PDOPS_PAUSED    = 2,
		PDOPS_CANCELLED = 3,
		PDOPS_STOPPED   = 4,
		PDOPS_ERRORS    = 5
	}
	alias int PDOPSTATUS;

	//extern extern(C) const IID IID_IOperationsProgressDialog;
	interface IOperationsProgressDialog : IUnknown {
	public extern(Windows):
		HRESULT StartProgressDialog(HWND hwndOwner, OPPROGDLGF flags);
		HRESULT StopProgressDialog();
		HRESULT SetOperation(SPACTION action);
		HRESULT SetMode(PDMODE mode);
		HRESULT UpdateProgress(ULONGLONG ullPointsCurrent, ULONGLONG ullPointsTotal, ULONGLONG ullSizeCurrent, ULONGLONG ullSizeTotal, ULONGLONG ullItemsCurrent, ULONGLONG ullItemsTotal);
		HRESULT UpdateLocations(IShellItem psiSource, IShellItem psiTarget, IShellItem psiItem);
		HRESULT ResetTimer();
		HRESULT PauseTimer();
		HRESULT ResumeTimer();
		HRESULT GetMilliseconds(ULONGLONG* pullElapsed, ULONGLONG* pullRemaining);
		HRESULT GetOperationStatus(PDOPSTATUS* popstatus);
	}
	mixin DEFINE_IID!(IOperationsProgressDialog, "0C9FB851-E5C9-43EB-A370-F0677B13874C");

	//extern extern(C) const IID IID_IIOCancelInformation;
	interface IIOCancelInformation : IUnknown {
	public extern(Windows):
		HRESULT SetCancelInformation(DWORD dwThreadID, UINT uMsgCancel);
		HRESULT GetCancelInformation(DWORD* pdwThreadID, UINT* puMsgCancel);
	}
	mixin DEFINE_IID!(IIOCancelInformation, "f5b0bf81-8cb5-4b1b-9449-1a159e0c733c");

	enum {
		FOFX_NOSKIPJUNCTIONS        = 0x00010000,
		FOFX_PREFERHARDLINK         = 0x00020000,
		FOFX_SHOWELEVATIONPROMPT    = 0x00040000,
		FOFX_EARLYFAILURE           = 0x00100000,
		FOFX_PRESERVEFILEEXTENSIONS = 0x00200000,
		FOFX_KEEPNEWERFILE          = 0x00400000,
		FOFX_NOCOPYHOOKS            = 0x00800000,
		FOFX_NOMINIMIZEBOX          = 0x01000000,
		FOFX_MOVEACLSACROSSVOLUMES  = 0x02000000,
		FOFX_DONTDISPLAYSOURCEPATH  = 0x04000000,
		FOFX_DONTDISPLAYDESTPATH    = 0x08000000,
		FOFX_REQUIREELEVATION       = 0x10000000,
		FOFX_COPYASDOWNLOAD         = 0x40000000,
		FOFX_DONTDISPLAYLOCATIONS   = 0x80000000,
	}

	//extern extern(C) const IID IID_IFileOperation;
	interface IFileOperation : IUnknown {
	public extern(Windows):
		HRESULT Advise(IFileOperationProgressSink pfops, DWORD* pdwCookie);
		HRESULT Unadvise(DWORD dwCookie);
		HRESULT SetOperationFlags(DWORD dwOperationFlags);
		HRESULT SetProgressMessage(LPCWSTR pszMessage);
		HRESULT SetProgressDialog(IOperationsProgressDialog popd);
		HRESULT SetProperties(IPropertyChangeArray pproparray);
		HRESULT SetOwnerWindow(HWND hwndOwner);
		HRESULT ApplyPropertiesToItem(IShellItem psiItem);
		HRESULT ApplyPropertiesToItems(IUnknown punkItems);
		HRESULT RenameItem(IShellItem psiItem, LPCWSTR pszNewName, IFileOperationProgressSink pfopsItem);
		HRESULT RenameItems(IUnknown pUnkItems, LPCWSTR pszNewName);
		HRESULT MoveItem(IShellItem psiItem, IShellItem psiDestinationFolder, LPCWSTR pszNewName, IFileOperationProgressSink pfopsItem);
		HRESULT MoveItems(IUnknown punkItems, IShellItem psiDestinationFolder);
		HRESULT CopyItem(IShellItem psiItem, IShellItem psiDestinationFolder, LPCWSTR pszCopyName, IFileOperationProgressSink pfopsItem);
		HRESULT CopyItems(IUnknown punkItems, IShellItem psiDestinationFolder);
		HRESULT DeleteItem(IShellItem psiItem, IFileOperationProgressSink pfopsItem);
		HRESULT DeleteItems(IUnknown punkItems);
		HRESULT NewItem(IShellItem psiDestinationFolder, DWORD dwFileAttributes, LPCWSTR pszName, LPCWSTR pszTemplateName, IFileOperationProgressSink pfopsItem);
		HRESULT PerformOperations();
		HRESULT GetAnyOperationsAborted(BOOL* pfAnyOperationsAborted);
	}
	mixin DEFINE_IID!(IFileOperation, "947aab5f-0a5c-4c13-b4d6-4bf7836fc9f8");

	//extern extern(C) const IID IID_IObjectProvider;
	interface IObjectProvider : IUnknown {
	public extern(Windows):
		HRESULT QueryObject(REFGUID guidObject, REFIID riid, void** ppvOut);
	}
	mixin DEFINE_IID!(IObjectProvider, "a6087428-3be3-4d73-b308-7c04a540bf1a");

	//extern extern(C) const IID IID_INamespaceWalkCB;
	interface INamespaceWalkCB : IUnknown {
	public extern(Windows):
		HRESULT FoundItem(IShellFolder psf, PCUITEMID_CHILD pidl);
		HRESULT EnterFolder(IShellFolder psf, PCUITEMID_CHILD pidl);
		HRESULT LeaveFolder(IShellFolder psf, PCUITEMID_CHILD pidl);
		HRESULT InitializeProgressDialog(LPWSTR* ppszTitle, LPWSTR* ppszCancel);
	}
	mixin DEFINE_IID!(INamespaceWalkCB, "d92995f8-cf5e-4a76-bf59-ead39ea2b97e");

	//(_WIN32_IE >= _WIN32_IE_IE70)
		//extern extern(C) const IID IID_INamespaceWalkCB2;
		interface INamespaceWalkCB2 : INamespaceWalkCB {
		public extern(Windows):
			HRESULT WalkComplete(HRESULT hr);
		}
		mixin DEFINE_IID!(INamespaceWalkCB2, "7ac7492b-c38e-438a-87db-68737844ff70");

	enum {
		NSWF_DEFAULT                        = 0,
		NSWF_NONE_IMPLIES_ALL               = 0x1,
		NSWF_ONE_IMPLIES_ALL                = 0x2,
		NSWF_DONT_TRAVERSE_LINKS            = 0x4,
		NSWF_DONT_ACCUMULATE_RESULT         = 0x8,
		NSWF_TRAVERSE_STREAM_JUNCTIONS      = 0x10,
		NSWF_FILESYSTEM_ONLY                = 0x20,
		NSWF_SHOW_PROGRESS                  = 0x40,
		NSWF_FLAG_VIEWORDER                 = 0x80,
		NSWF_IGNORE_AUTOPLAY_HIDA           = 0x100,
		NSWF_ASYNC                          = 0x200,
		NSWF_DONT_RESOLVE_LINKS             = 0x400,
		NSWF_ACCUMULATE_FOLDERS             = 0x800,
		NSWF_DONT_SORT                      = 0x1000,
		NSWF_USE_TRANSFER_MEDIUM            = 0x2000,
		NSWF_DONT_TRAVERSE_STREAM_JUNCTIONS = 0x4000
	}
	alias int NAMESPACEWALKFLAG;

	//extern extern(C) const IID IID_INamespaceWalk;
	mixin DEFINE_GUID!(INamespaceWalk, "57ced8a7-3f4a-432c-9350-30f24483f74f");
	interface INamespaceWalk : IUnknown {
	public extern(Windows):
		HRESULT Walk(IUnknown punkToWalk, DWORD dwFlags, int cDepth, INamespaceWalkCB pnswcb);
		HRESULT GetIDArrayResult(UINT* pcItems, PIDLIST_ABSOLUTE** prgpidl);
	}

void FreeIDListArray(PIDLIST_RELATIVE* ppidls, UINT cItems)
{
	UINT i;

	for(i = 0; i < cItems; i++){
		CoTaskMemFree(ppidls[i]);
	}
	CoTaskMemFree(ppidls);
}

void FreeIDListArrayFull(PIDLIST_ABSOLUTE* ppidls, UINT cItems)
{
	for(UINT i = 0; i < cItems; i++){
		CoTaskMemFree(ppidls[i]);
	}
	CoTaskMemFree(ppidls);
}

void FreeIDListArrayChild(PITEMID_CHILD* ppidls, UINT cItems)
{
	for(UINT i = 0; i < cItems; i++){
		CoTaskMemFree(ppidls[i]);
	}
	CoTaskMemFree(ppidls);
}

enum ACDD_VISIBLE = 0x0001;

//extern extern(C) const IID IID_IAutoCompleteDropDown;
interface IAutoCompleteDropDown : IUnknown {
public extern(Windows):
	HRESULT GetDropDownStatus(DWORD* pdwFlags, LPWSTR* ppwszString);
	HRESULT ResetEnumerator();
}
mixin DEFINE_IID!(IAutoCompleteDropDown, "3CD141F4-3C6A-11d2-BCAA-00C04FD929DB");

align(8)
struct BANDSITEINFO {
	DWORD dwMask;
	DWORD dwState;
	DWORD dwStyle;
}

enum {
	BSID_BANDADDED,
	BSID_BANDREMOVED,
}
alias int BANDSITECID;

enum {
	BSIM_STATE             = 0x00000001,
	BSIM_STYLE             = 0x00000002,
	BSSF_VISIBLE           = 0x00000001,
	BSSF_NOTITLE           = 0x00000002,
	BSSF_UNDELETEABLE      = 0x00001000,
	BSIS_AUTOGRIPPER       = 0x00000000,
	BSIS_NOGRIPPER         = 0x00000001,
	BSIS_ALWAYSGRIPPER     = 0x00000002,
	BSIS_LEFTALIGN         = 0x00000004,
	BSIS_SINGLECLICK       = 0x00000008,
	BSIS_NOCONTEXTMENU     = 0x00000010,
	BSIS_NODROPTARGET      = 0x00000020,
	BSIS_NOCAPTION         = 0x00000040,
	BSIS_PREFERNOLINEBREAK = 0x00000080,
	BSIS_LOCKED            = 0x00000100,
	//(_WIN32_IE >= _WIN32_IE_IE70)
		BSIS_PRESERVEORDERDURINGLAYOUT = 0x00000200,
		BSIS_FIXEDORDER                = 0x00000400,
}

//extern extern(C) const IID IID_IBandSite;
interface IBandSite : IUnknown {
public extern(Windows):
	HRESULT AddBand(IUnknown punk);
	HRESULT EnumBands(UINT uBand, DWORD* pdwBandID);
	HRESULT QueryBand(DWORD dwBandID, IDeskBand* ppstb, DWORD* pdwState, LPWSTR pszName, int cchName);
	HRESULT SetBandState(DWORD dwBandID, DWORD dwMask, DWORD dwState);
	HRESULT RemoveBand(DWORD dwBandID);
	HRESULT GetBandObject(DWORD dwBandID, REFIID riid, void** ppv);
	HRESULT SetBandSiteInfo(const(BANDSITEINFO)* pbsinfo);
	HRESULT GetBandSiteInfo(BANDSITEINFO* pbsinfo);
}
mixin DEFINE_IID!(IBandSite, "4CF504B0-DE96-11D0-8B3F-00A0C911E8E5");
alias IID_IBandSite SID_SBandSite;
alias IID_IBandSite CGID_BandSite;

export extern(Windows){
	HRESULT IBandSite_RemoteQueryBand_Proxy(IBandSite This, DWORD dwBandID, IDeskBand* ppstb, DWORD* pdwState, LPWSTR pszName, int cchName);
	void IBandSite_RemoteQueryBand_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
}

//(NTDDI_VERSION >= NTDDI_WINXP)
	//extern extern(C) const IID IID_IModalWindow;
	interface IModalWindow : IUnknown {
	public extern(Windows):
		HRESULT Show(HWND hwndOwner);
	}
	mixin DEFINE_IID!(IModalWindow, "b4db1657-70d7-485e-8e3e-6fcb5a5c1802");

	export extern(Windows){
		HRESULT IModalWindow_RemoteShow_Proxy(IModalWindow This, HWND hwndOwner);
		void IModalWindow_RemoteShow_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}

	const wchar* PROPSTR_EXTENSIONCOMPLETIONSTATE = "ExtensionCompletionState";

	enum {
		CDBE_RET_DEFAULT          = 0,
		CDBE_RET_DONTRUNOTHEREXTS = 0x1,
		CDBE_RET_STOPWIZARD       = 0x2
	}
	alias int CDBURNINGEXTENSIONRET;

	enum {
		CDBE_TYPE_MUSIC = 0x1,
		CDBE_TYPE_DATA  = 0x2,
		CDBE_TYPE_ALL   = cast(int)0xffffffff
	}
	alias DWORD CDBE_ACTIONS;

	//extern extern(C) const IID IID_ICDBurnExt;
	interface ICDBurnExt : IUnknown {
	public extern(Windows):
		HRESULT GetSupportedActionTypes(CDBE_ACTIONS* pdwActions);
	}
	mixin DEFINE_IID!(ICDBurnExt, "2271dcca-74fc-4414-8fb7-c56b05ace2d7");
	alias IID_ICDBurnExt SID_CDWizardHost;

//extern extern(C) const IID IID_IContextMenuSite;
interface IContextMenuSite : IUnknown {
public extern(Windows):
	HRESULT DoContextMenuPopup(IUnknown punkContextMenu, UINT fFlags, POINT pt);
}
mixin DEFINE_IID!(IContextMenuSite, "0811AEBE-0B87-4C54-9E72-548CF649016B");

//extern extern(C) const IID IID_IEnumReadyCallback;
interface IEnumReadyCallback : IUnknown {
public extern(Windows):
	HRESULT EnumReady();
}
mixin DEFINE_IID!(IEnumReadyCallback, "61E00D45-8FFF-4e60-924E-6537B61612DD");

//extern extern(C) const IID IID_IEnumerableView;
interface IEnumerableView : IUnknown {
public extern(Windows):
	HRESULT SetEnumReadyCallback(IEnumReadyCallback percb);
	HRESULT CreateEnumIDListFromContents(PCIDLIST_ABSOLUTE pidlFolder, DWORD dwEnumFlags, IEnumIDList* ppEnumIDList);
}
mixin DEFINE_IID!(IEnumerableView, "8C8BF236-1AEC-495f-9894-91D57C3C686F");
alias IID_IEnumerableView SID_EnumerableView;

//(NTDDI_VERSION >= NTDDI_WINXP) || (_WIN32_IE >= _WIN32_IE_IE70)
	//extern extern(C) const IID IID_IInsertItem;
	interface IInsertItem : IUnknown {
	public extern(Windows):
		HRESULT InsertItem(PCUIDLIST_RELATIVE pidl);
	}
	mixin DEFINE_IID!(IInsertItem, "D2B57227-3D23-4b95-93C0-492BD454C356");

	//(NTDDI_VERSION >= NTDDI_WINXP)
		enum {
			MBHANDCID_PIDLSELECT = 0
		}

		//extern extern(C) const IID IID_IMenuBand;
		interface IMenuBand : IUnknown {
		public extern(Windows):
			HRESULT IsMenuMessage(MSG* pmsg);
			HRESULT TranslateMenuMessage(MSG* pmsg, LRESULT* plRet);
		}
		mixin DEFINE_IID!(IMenuBand, "568804CD-CBD7-11d0-9816-00C04FD91972");

		//extern extern(C) const IID IID_IFolderBandPriv;
		interface IFolderBandPriv : IUnknown {
		public extern(Windows):
			HRESULT SetCascade(BOOL fCascade);
			HRESULT SetAccelerators(BOOL fAccelerators);
			HRESULT SetNoIcons(BOOL fNoIcons);
			HRESULT SetNoText(BOOL fNoText);
		}
		mixin DEFINE_IID!(IFolderBandPriv, "47c01f95-e185-412c-b5c5-4f27df965aea");

		//extern extern(C) const IID IID_IRegTreeItem;
		interface IRegTreeItem : IUnknown {
		public extern(Windows):
			HRESULT GetCheckState(BOOL* pbCheck);
			HRESULT SetCheckState(BOOL bCheck);
		}
		mixin DEFINE_IID!(IRegTreeItem, "A9521922-0812-4d44-9EC3-7FD38C726F3D");

		//extern extern(C) const IID IID_IImageRecompress;
		interface IImageRecompress : IUnknown {
		public extern(Windows):
			HRESULT RecompressImage(IShellItem psi, int cx, int cy, int iQuality, IStorage pstg, IStream* ppstrmOut);
		}
		mixin DEFINE_IID!(IImageRecompress, "505f1513-6b3e-4892-a272-59f8889a4d3e");

//extern extern(C) const IID IID_IDeskBar;
interface IDeskBar : IOleWindow {
public extern(Windows):
	HRESULT SetClient(IUnknown punkClient);
	HRESULT GetClient(IUnknown* ppunkClient);
	HRESULT OnPosRectChangeDB(RECT* prc);
}
mixin DEFINE_IID!(IDeskBar, "EB0FE173-1A3A-11D0-89B3-00A0C90A90AC");

enum {
	MPOS_EXECUTE,
	MPOS_FULLCANCEL,
	MPOS_CANCELLEVEL,
	MPOS_SELECTLEFT,
	MPOS_SELECTRIGHT,
	MPOS_CHILDTRACKING,
}

enum {
	MPPF_SETFOCUS      = 0x1,
	MPPF_INITIALSELECT = 0x2,
	MPPF_NOANIMATE     = 0x4,
	MPPF_KEYBOARD      = 0x10,
	MPPF_REPOSITION    = 0x20,
	MPPF_FORCEZORDER   = 0x40,
	MPPF_FINALSELECT   = 0x80,
	MPPF_TOP           = 0x20000000,
	MPPF_LEFT          = 0x40000000,
	MPPF_RIGHT         = 0x60000000,
	MPPF_BOTTOM        = cast(int)0x80000000,
	MPPF_POS_MASK      = cast(int)0xe0000000,
	MPPF_ALIGN_LEFT    = 0x2000000,
	MPPF_ALIGN_RIGHT   = 0x4000000
}
alias int MP_POPUPFLAGS;

//extern extern(C) const IID IID_IMenuPopup;
interface IMenuPopup : IDeskBar {
public extern(Windows):
	HRESULT Popup(POINTL* ppt, RECTL* prcExclude, MP_POPUPFLAGS dwFlags);
	HRESULT OnSelect(DWORD dwSelectType);
	HRESULT SetSubMenu(IMenuPopup pmp, BOOL fSet);
}
mixin DEFINE_IID!(IMenuPopup, "D1E7AFEB-6A2E-11d0-8C78-00C04FD918B4");

//(NTDDI_VERSION >= NTDDI_VISTA)
	enum {
		FUT_PLAYING,
		FUT_EDITING,
		FUT_GENERIC,
	}
	alias int FILE_USAGE_TYPE;

	enum {
		OF_CAP_CANSWITCHTO = 0x0001,
		OF_CAP_CANCLOSE    = 0x0002,
	}

	//extern extern(C) const IID IID_IFileIsInUse;
	interface IFileIsInUse : IUnknown {
	public extern(Windows):
		HRESULT GetAppName(LPWSTR* ppszName);
		HRESULT GetUsage(FILE_USAGE_TYPE* pfut);
		HRESULT GetCapabilities(DWORD* pdwCapFlags);
		HRESULT GetSwitchToHWND(HWND* phwnd);
		HRESULT CloseFile();
	}
	mixin DEFINE_IID!(IFileIsInUse, "64a1cbf0-3a1a-4461-9158-376969693950");

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

	//extern extern(C) const IID IID_IFileOpenDialog;
	interface IFileOpenDialog : IFileDialog {
	public extern(Windows):
		HRESULT GetResults(IShellItemArray* ppenum);
		HRESULT GetSelectedItems(IShellItemArray* ppsai);
	}
	mixin DEFINE_IID!(IFileOpenDialog, "d57c7288-d4ad-4768-be02-9d969532d960");

	enum {
		CDCS_INACTIVE       = 0,
		CDCS_ENABLED        = 0x1,
		CDCS_VISIBLE        = 0x2,
		CDCS_ENABLEDVISIBLE = 0x3
	}
	alias int CDCONTROLSTATEF;

	//extern extern(C) const IID IID_IFileDialogCustomize;
	interface IFileDialogCustomize : IUnknown {
	public extern(Windows):
		HRESULT EnableOpenDropDown(DWORD dwIDCtl);
		HRESULT AddMenu(DWORD dwIDCtl, LPCWSTR pszLabel);
		HRESULT AddPushButton(DWORD dwIDCtl, LPCWSTR pszLabel);
		HRESULT AddComboBox(DWORD dwIDCtl);
		HRESULT AddRadioButtonList(DWORD dwIDCtl);
		HRESULT AddCheckButton(DWORD dwIDCtl, LPCWSTR pszLabel, BOOL bChecked);
		HRESULT AddEditBox(DWORD dwIDCtl, LPCWSTR pszText);
		HRESULT AddSeparator(DWORD dwIDCtl);
		HRESULT AddText(DWORD dwIDCtl, LPCWSTR pszText);
		HRESULT SetControlLabel(DWORD dwIDCtl, LPCWSTR pszLabel);
		HRESULT GetControlState(DWORD dwIDCtl, CDCONTROLSTATEF* pdwState);
		HRESULT SetControlState(DWORD dwIDCtl, CDCONTROLSTATEF dwState);
		HRESULT GetEditBoxText(DWORD dwIDCtl, WCHAR** ppszText);
		HRESULT SetEditBoxText(DWORD dwIDCtl, LPCWSTR pszText);
		HRESULT GetCheckButtonState(DWORD dwIDCtl, BOOL* pbChecked);
		HRESULT SetCheckButtonState(DWORD dwIDCtl, BOOL bChecked);
		HRESULT AddControlItem(DWORD dwIDCtl, DWORD dwIDItem, LPCWSTR pszLabel);
		HRESULT RemoveControlItem(DWORD dwIDCtl, DWORD dwIDItem);
		HRESULT RemoveAllControlItems(DWORD dwIDCtl);
		HRESULT GetControlItemState(DWORD dwIDCtl, DWORD dwIDItem, CDCONTROLSTATEF* pdwState);
		HRESULT SetControlItemState(DWORD dwIDCtl, DWORD dwIDItem, CDCONTROLSTATEF dwState);
		HRESULT GetSelectedControlItem(DWORD dwIDCtl, DWORD* pdwIDItem);
		HRESULT SetSelectedControlItem(DWORD dwIDCtl, DWORD dwIDItem);
		HRESULT StartVisualGroup(DWORD dwIDCtl, LPCWSTR pszLabel);
		HRESULT EndVisualGroup();
		HRESULT MakeProminent(DWORD dwIDCtl);
		HRESULT SetControlItemText(DWORD dwIDCtl, DWORD dwIDItem, LPCWSTR pszLabel);
	}
	mixin DEFINE_IID!(IFileDialogCustomize, "e6fdd21a-163f-4975-9c8c-a69f1ba37034");

	//extern extern(C) const IID IID_IFileDialogControlEvents;
	interface IFileDialogControlEvents : IUnknown {
	public extern(Windows):
		HRESULT OnItemSelected(IFileDialogCustomize pfdc, DWORD dwIDCtl, DWORD dwIDItem);
		HRESULT OnButtonClicked(IFileDialogCustomize pfdc, DWORD dwIDCtl);
		HRESULT OnCheckButtonToggled(IFileDialogCustomize pfdc, DWORD dwIDCtl, BOOL bChecked);
		HRESULT OnControlActivating(IFileDialogCustomize pfdc, DWORD dwIDCtl);
	}
	mixin DEFINE_IID!(IFileDialogControlEvents, "36116642-D713-4b97-9B83-7484A9D00433");

	//extern extern(C) const IID IID_IFileDialog2;
	interface IFileDialog2 : IFileDialog {
	public extern(Windows):
		HRESULT SetCancelButtonLabel(LPCWSTR pszLabel);
		HRESULT SetNavigationRoot(IShellItem psi);
	}
	mixin DEFINE_GUID!(IFileDialog2, "61744fc7-85b5-4791-a9b0-272276309b13");

	enum {
		AL_MACHINE,
		AL_EFFECTIVE,
		AL_USER,
	}
	alias int ASSOCIATIONLEVEL;

	enum {
		AT_FILEEXTENSION,
		AT_URLPROTOCOL,
		AT_STARTMENUCLIENT,
		AT_MIMETYPE
	}
	alias int ASSOCIATIONTYPE;

	//extern extern(C) const IID IID_IApplicationAssociationRegistration;
	interface IApplicationAssociationRegistration : IUnknown {
	public extern(Windows):
		HRESULT QueryCurrentDefault(LPCWSTR pszQuery, ASSOCIATIONTYPE atQueryType, ASSOCIATIONLEVEL alQueryLevel, LPWSTR* ppszAssociation);
		HRESULT QueryAppIsDefault(LPCWSTR pszQuery, ASSOCIATIONTYPE atQueryType, ASSOCIATIONLEVEL alQueryLevel, LPCWSTR pszAppRegistryName, BOOL* pfDefault);
		HRESULT QueryAppIsDefaultAll(ASSOCIATIONLEVEL alQueryLevel, LPCWSTR pszAppRegistryName, BOOL* pfDefault);
		HRESULT SetAppAsDefault(LPCWSTR pszAppRegistryName, LPCWSTR pszSet, ASSOCIATIONTYPE atSetType);
		HRESULT SetAppAsDefaultAll(LPCWSTR pszAppRegistryName);
		HRESULT ClearUserAssociations();
	}
	mixin DEFINE_IID!(IApplicationAssociationRegistration, "4e530b0a-e611-4c77-a3ac-9031d022281b");

static if(NTDDI_VERSION >= NTDDI_VISTA)
	export extern(Windows) HRESULT SHCreateAssociationRegistration(REFIID riid, void** ppv);

	//extern extern(C) const IID IID_IApplicationAssociationRegistrationUI;
	interface IApplicationAssociationRegistrationUI : IUnknown {
	public extern(Windows):
		HRESULT LaunchAdvancedAssociationUI(LPCWSTR pszAppRegistryName);
	}
	mixin DEFINE_IID!(IApplicationAssociationRegistrationUI, "1f76a169-f994-40ac-8fc8-0959e8874710");

align(1)
struct DELEGATEITEMID {
	WORD cbSize;
	WORD wOuter;
	WORD cbInner;
	BYTE[1] rgb;
}
alias const(DELEGATEITEMID)* PCDELEGATEITEMID;
alias DELEGATEITEMID* PDELEGATEITEMID;

//extern extern(C) const IID IID_IDelegateFolder;
interface IDelegateFolder : IUnknown {
public extern(Windows):
	HRESULT SetItemAlloc(IMalloc pmalloc);
}
mixin DEFINE_IID!(IDelegateFolder, "ADD8BA80-002B-11D0-8F0F-00C04FD7D062");
alias IBrowserFrameOptions LPBROWSERFRAMEOPTIONS;

enum {
	BFO_NONE                             = 0,
	BFO_BROWSER_PERSIST_SETTINGS         = 0x1,
	BFO_RENAME_FOLDER_OPTIONS_TOINTERNET = 0x2,
	BFO_BOTH_OPTIONS                     = 0x4,
	BIF_PREFER_INTERNET_SHORTCUT         = 0x8,
	BFO_BROWSE_NO_IN_NEW_PROCESS         = 0x10,
	BFO_ENABLE_HYPERLINK_TRACKING        = 0x20,
	BFO_USE_IE_OFFLINE_SUPPORT           = 0x40,
	BFO_SUBSTITUE_INTERNET_START_PAGE    = 0x80,
	BFO_USE_IE_LOGOBANDING               = 0x100,
	BFO_ADD_IE_TOCAPTIONBAR              = 0x200,
	BFO_USE_DIALUP_REF                   = 0x400,
	BFO_USE_IE_TOOLBAR                   = 0x800,
	BFO_NO_PARENT_FOLDER_SUPPORT         = 0x1000,
	BFO_NO_REOPEN_NEXT_RESTART           = 0x2000,
	BFO_GO_HOME_PAGE                     = 0x4000,
	BFO_PREFER_IEPROCESS                 = 0x8000,
	BFO_SHOW_NAVIGATION_CANCELLED        = 0x10000,
	BFO_USE_IE_STATUSBAR                 = 0x20000,
	BFO_QUERY_ALL                        = cast(int)0xffffffff
}
alias DWORD BROWSERFRAMEOPTIONS;

//extern extern(C) const IID IID_IBrowserFrameOptions;
interface IBrowserFrameOptions : IUnknown {
public extern(Windows):
	HRESULT GetFrameOptions(BROWSERFRAMEOPTIONS dwMask, BROWSERFRAMEOPTIONS* pdwOptions);
}
mixin DEFINE_IID!(IBrowserFrameOptions, "10DF43C8-1DBE-11d3-8B34-006097DF5BD4");

enum {
	NWMF_UNLOADING       = 0x1,
	NWMF_USERINITED      = 0x2,
	NWMF_FIRST           = 0x4,
	NWMF_OVERRIDEKEY     = 0x8,
	NWMF_SHOWHELP        = 0x10,
	NWMF_HTMLDIALOG      = 0x20,
	NWMF_FROMDIALOGCHILD = 0x40,
	NWMF_USERREQUESTED   = 0x80,
	NWMF_USERALLOWED     = 0x100,
	NWMF_FORCEWINDOW     = 0x10000,
	NWMF_FORCETAB        = 0x20000,
	NWMF_SUGGESTWINDOW   = 0x40000,
	NWMF_SUGGESTTAB      = 0x80000,
	NWMF_INACTIVETAB     = 0x100000
}
alias int NWMF;

//extern extern(C) const IID IID_INewWindowManager;
interface INewWindowManager : IUnknown {
public extern(Windows):
	HRESULT EvaluateNewWindow(LPCWSTR pszUrl, LPCWSTR pszName, LPCWSTR pszUrlContext, LPCWSTR pszFeatures, BOOL fReplace, DWORD dwFlags, DWORD dwUserActionTime);
}
mixin DEFINE_IID!(INewWindowManager, "D2BC4C84-3F72-4a52-A604-7BCBF3982CBB");
alias IID_INewWindowManager SID_SNewWindowManager;

enum {
	ATTACHMENT_PROMPT_NONE         = 0,
	ATTACHMENT_PROMPT_SAVE         = 0x1,
	ATTACHMENT_PROMPT_EXEC         = 0x2,
	ATTACHMENT_PROMPT_EXEC_OR_SAVE = 0x3
}
alias int ATTACHMENT_PROMPT;

enum {
	ATTACHMENT_ACTION_CANCEL = 0,
	ATTACHMENT_ACTION_SAVE   = 0x1,
	ATTACHMENT_ACTION_EXEC   = 0x2
}
alias int ATTACHMENT_ACTION;

//extern extern(C) const IID IID_IAttachmentExecute;
interface IAttachmentExecute : IUnknown {
public extern(Windows):
	HRESULT SetClientTitle(LPCWSTR pszTitle);
	HRESULT SetClientGuid(REFGUID guid);
	HRESULT SetLocalPath(LPCWSTR pszLocalPath);
	HRESULT SetFileName(LPCWSTR pszFileName);
	HRESULT SetSource(LPCWSTR pszSource);
	HRESULT SetReferrer(LPCWSTR pszReferrer);
	HRESULT CheckPolicy();
	HRESULT Prompt(HWND hwnd, ATTACHMENT_PROMPT prompt, ATTACHMENT_ACTION* paction);
	HRESULT Save();
	HRESULT Execute(HWND hwnd, LPCWSTR pszVerb, HANDLE* phProcess);
	HRESULT SaveWithUI(HWND hwnd);
	HRESULT ClearClientState();
}
mixin DEFINE_IID!(IAttachmentExecute, "73db1241-1e85-4581-8e4f-a81e1d0f8c57");

align(8)
struct SMDATA {
	DWORD dwMask;
	DWORD dwFlags;
	HMENU hmenu;
	HWND hwnd;
	UINT uId;
	UINT uIdParent;
	UINT uIdAncestor;
	IUnknown punk;
	PIDLIST_ABSOLUTE pidlFolder;
	PUITEMID_CHILD pidlItem;
	IShellFolder psf;
	void* pvUserData;
}
alias SMDATA* LPSMDATA;

enum {
	SMDM_SHELLFOLDER = 0x00000001,
	SMDM_HMENU       = 0x00000002,
	SMDM_TOOLBAR     = 0x00000004,
}

align(8)
struct SMINFO {
	DWORD dwMask;
	DWORD dwType;
	DWORD dwFlags;
	int iIcon;
}
alias SMINFO* PSMINFO;

align(8)
struct SMCSHCHANGENOTIFYSTRUCT {
	int lEvent;
	PCIDLIST_ABSOLUTE pidl1;
	PCIDLIST_ABSOLUTE pidl2;
}
alias SMCSHCHANGENOTIFYSTRUCT* PSMCSHCHANGENOTIFYSTRUCT;

enum {
	SMIM_TYPE  = 0x1,
	SMIM_FLAGS = 0x2,
	SMIM_ICON  = 0x4
}

enum {
	SMIT_SEPARATOR = 0x1,
	SMIT_STRING    = 0x2
}

enum {
	SMIF_ICON        = 0x1,
	SMIF_ACCELERATOR = 0x2,
	SMIF_DROPTARGET  = 0x4,
	SMIF_SUBMENU     = 0x8,
	SMIF_CHECKED     = 0x20,
	SMIF_DROPCASCADE = 0x40,
	SMIF_HIDDEN      = 0x80,
	SMIF_DISABLED    = 0x100,
	SMIF_TRACKPOPUP  = 0x200,
	SMIF_DEMOTED     = 0x400,
	SMIF_ALTSTATE    = 0x800,
	SMIF_DRAGNDROP   = 0x1000,
	SMIF_NEW         = 0x2000
}
enum {
	SMC_INITMENU          = 0x00000001,
	SMC_CREATE            = 0x00000002,
	SMC_EXITMENU          = 0x00000003,
	SMC_GETINFO           = 0x00000005,
	SMC_GETSFINFO         = 0x00000006,
	SMC_GETOBJECT         = 0x00000007,
	SMC_GETSFOBJECT       = 0x00000008,
	SMC_SFEXEC            = 0x00000009,
	SMC_SFSELECTITEM      = 0x0000000A,
	SMC_REFRESH           = 0x00000010,
	SMC_DEMOTE            = 0x00000011,
	SMC_PROMOTE           = 0x00000012,
	SMC_DEFAULTICON       = 0x00000016,
	SMC_NEWITEM           = 0x00000017,
	SMC_CHEVRONEXPAND     = 0x00000019,
	SMC_DISPLAYCHEVRONTIP = 0x0000002A,
	SMC_SETSFOBJECT       = 0x0000002D,
	SMC_SHCHANGENOTIFY    = 0x0000002E,
	SMC_CHEVRONGETTIP     = 0x0000002F,
	SMC_SFDDRESTRICTED    = 0x00000030,
	//(_WIN32_IE >= _WIN32_IE_IE70)
		SMC_SFEXEC_MIDDLE          = 0x00000031,
		SMC_GETAUTOEXPANDSTATE     = 0x00000041,
		SMC_AUTOEXPANDCHANGE       = 0x00000042,
		SMC_GETCONTEXTMENUMODIFIER = 0x00000043,
		SMC_GETBKCONTEXTMENU       = 0x00000044,
		SMC_OPEN                   = 0x00000045,
		SMAE_EXPANDED              = 0x00000001,
		SMAE_CONTRACTED            = 0x00000002,
		SMAE_USER                  = 0x00000004,
		SMAE_VALID                 = 0x00000007,
}

//extern extern(C) const IID IID_IShellMenuCallback;
interface IShellMenuCallback : IUnknown {
public extern(Windows):
	HRESULT CallbackSM(LPSMDATA psmd, UINT uMsg, WPARAM wParam, LPARAM lParam);
}
mixin DEFINE_IID!(IShellMenuCallback, "4CA300A1-9B8D-11d1-8B22-00C04FD918D0");

enum {
	SMINIT_DEFAULT           = 0x00000000,
	SMINIT_RESTRICT_DRAGDROP = 0x00000002,
	SMINIT_TOPLEVEL          = 0x00000004,
	SMINIT_CACHED            = 0x00000010,
	//(_WIN32_IE >= _WIN32_IE_IE70)
		SMINIT_AUTOEXPAND      = 0x00000100,
		SMINIT_AUTOTOOLTIP     = 0x00000200,
		SMINIT_DROPONCONTAINER = 0x00000400,
	SMINIT_VERTICAL   = 0x10000000,
	SMINIT_HORIZONTAL = 0x20000000,
	ANCESTORDEFAULT   = cast(UINT)-1,
	SMSET_TOP         = 0x10000000,
	SMSET_BOTTOM      = 0x20000000,
	SMSET_DONTOWN     = 0x00000001,
	SMINV_REFRESH     = 0x00000001,
	SMINV_ID          = 0x00000008,
}

//extern extern(C) const IID IID_IShellMenu;
interface IShellMenu : IUnknown {
public extern(Windows):
	HRESULT Initialize(IShellMenuCallback psmc, UINT uId, UINT uIdAncestor, DWORD dwFlags);
	HRESULT GetMenuInfo(IShellMenuCallback* ppsmc, UINT* puId, UINT* puIdAncestor, DWORD* pdwFlags);
	HRESULT SetShellFolder(IShellFolder psf, PCIDLIST_ABSOLUTE pidlFolder, HKEY hKey, DWORD dwFlags);
	HRESULT GetShellFolder(DWORD* pdwFlags, PIDLIST_ABSOLUTE* ppidl, REFIID riid, void** ppv);
	HRESULT SetMenu(HMENU hmenu, HWND hwnd, DWORD dwFlags);
	HRESULT GetMenu(HMENU* phmenu, HWND* phwnd, DWORD* pdwFlags);
	HRESULT InvalidateItem(LPSMDATA psmd, DWORD dwFlags);
	HRESULT GetState(LPSMDATA psmd);
	HRESULT SetMenuToolbar(IUnknown punk, DWORD dwFlags);
}
mixin DEFINE_IID!(IShellMenu, "EE1F7637-E138-11d1-8379-00C04FD918D0");

//extern extern(C) const IID IID_IShellRunDll;
interface IShellRunDll : IUnknown {
public extern(Windows):
	HRESULT Run(LPCWSTR pszArgs);
}
mixin DEFINE_IID!(IShellRunDll, "fce4bde0-4b68-4b80-8e9c-7426315a7388");

//(NTDDI_VERSION >= NTDDI_VISTA)
	enum {
		KF_CATEGORY_VIRTUAL = 1,
		KF_CATEGORY_FIXED   = 2,
		KF_CATEGORY_COMMON  = 3,
		KF_CATEGORY_PERUSER = 4
	}
	alias int KF_CATEGORY;

	enum {
		KFDF_LOCAL_REDIRECT_ONLY = 0x2,
		KFDF_ROAMABLE            = 0x4,
		KFDF_PRECREATE           = 0x8,
		KFDF_STREAM              = 0x10,
		KFDF_PUBLISHEXPANDEDPATH = 0x20
	}
	alias DWORD KF_DEFINITION_FLAGS;

	enum {
		KF_REDIRECT_USER_EXCLUSIVE               = 0x1,
		KF_REDIRECT_COPY_SOURCE_DACL             = 0x2,
		KF_REDIRECT_OWNER_USER                   = 0x4,
		KF_REDIRECT_SET_OWNER_EXPLICIT           = 0x8,
		KF_REDIRECT_CHECK_ONLY                   = 0x10,
		KF_REDIRECT_WITH_UI                      = 0x20,
		KF_REDIRECT_UNPIN                        = 0x40,
		KF_REDIRECT_PIN                          = 0x80,
		KF_REDIRECT_COPY_CONTENTS                = 0x200,
		KF_REDIRECT_DEL_SOURCE_CONTENTS          = 0x400,
		KF_REDIRECT_EXCLUDE_ALL_KNOWN_SUBFOLDERS = 0x800
	}
	alias DWORD KF_REDIRECT_FLAGS;

	enum {
		KF_REDIRECTION_CAPABILITIES_ALLOW_ALL              = 0xff,
		KF_REDIRECTION_CAPABILITIES_REDIRECTABLE           = 0x1,
		KF_REDIRECTION_CAPABILITIES_DENY_ALL               = 0xfff00,
		KF_REDIRECTION_CAPABILITIES_DENY_POLICY_REDIRECTED = 0x100,
		KF_REDIRECTION_CAPABILITIES_DENY_POLICY            = 0x200,
		KF_REDIRECTION_CAPABILITIES_DENY_PERMISSIONS       = 0x400
	}
	alias DWORD KF_REDIRECTION_CAPABILITIES;

	struct KNOWNFOLDER_DEFINITION {
		KF_CATEGORY category;
		LPWSTR pszName;
		LPWSTR pszDescription;
		KNOWNFOLDERID fidParent;
		LPWSTR pszRelativePath;
		LPWSTR pszParsingName;
		LPWSTR pszTooltip;
		LPWSTR pszLocalizedName;
		LPWSTR pszIcon;
		LPWSTR pszSecurity;
		DWORD dwAttributes;
		KF_DEFINITION_FLAGS kfdFlags;
		FOLDERTYPEID ftidType;
	}

	//extern extern(C) const IID IID_IKnownFolder;
	interface IKnownFolder : IUnknown {
	public extern(Windows):
		HRESULT GetId(KNOWNFOLDERID* pkfid);
		HRESULT GetCategory(KF_CATEGORY* pCategory);
		HRESULT GetShellItem(DWORD dwFlags, REFIID riid, void** ppv);
		HRESULT GetPath(DWORD dwFlags, LPWSTR* ppszPath);
		HRESULT SetPath(DWORD dwFlags, LPCWSTR pszPath);
		HRESULT GetIDList(DWORD dwFlags, PIDLIST_ABSOLUTE* ppidl);
		HRESULT GetFolderType(FOLDERTYPEID* pftid);
		HRESULT GetRedirectionCapabilities(KF_REDIRECTION_CAPABILITIES* pCapabilities);
		HRESULT GetFolderDefinition(KNOWNFOLDER_DEFINITION* pKFD);
	}
	mixin DEFINE_IID!(IKnownFolder, "3AA7AF7E-9B36-420c-A8E3-F77D4674A488");

	enum {
		FFFP_EXACTMATCH,
		FFFP_NEARESTPARENTMATCH,
	}
	alias int FFFP_MODE;

	//extern extern(C) const IID IID_IKnownFolderManager;
	interface IKnownFolderManager : IUnknown {
	public extern(Windows):
		HRESULT FolderIdFromCsidl(int nCsidl, KNOWNFOLDERID* pfid);
		HRESULT FolderIdToCsidl(REFKNOWNFOLDERID rfid, int* pnCsidl);
		HRESULT GetFolderIds(KNOWNFOLDERID** ppKFId, UINT* pCount);
		HRESULT GetFolder(REFKNOWNFOLDERID rfid, IKnownFolder* ppkf);
		HRESULT GetFolderByName(LPCWSTR pszCanonicalName, IKnownFolder* ppkf);
		HRESULT RegisterFolder(REFKNOWNFOLDERID rfid, const(KNOWNFOLDER_DEFINITION)* pKFD);
		HRESULT UnregisterFolder(REFKNOWNFOLDERID rfid);
		HRESULT FindFolderFromPath(LPCWSTR pszPath, FFFP_MODE mode, IKnownFolder* ppkf);
		HRESULT FindFolderFromIDList(PCIDLIST_ABSOLUTE pidl, IKnownFolder* ppkf);
		HRESULT Redirect(REFKNOWNFOLDERID rfid, HWND hwnd, KF_REDIRECT_FLAGS flags, LPCWSTR pszTargetPath, UINT cFolders, const(KNOWNFOLDERID)* pExclusion, LPWSTR* ppszError);
	}
	mixin DEFINE_IID!(IKnownFolderManager, "8BE2D872-86AA-4d47-B776-32CCA40C7018");

static if(NTDDI_VERSION >= NTDDI_VISTA){
	export extern(Windows){
		HRESULT IKnownFolderManager_RemoteRedirect_Proxy(IKnownFolderManager This, REFKNOWNFOLDERID rfid, HWND hwnd, KF_REDIRECT_FLAGS flags, LPCWSTR pszTargetPath, UINT cFolders, const(GUID)* pExclusion, LPWSTR* ppszError);
		void IKnownFolderManager_RemoteRedirect_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
	}
}
	void FreeKnownFolderDefinitionFields(KNOWNFOLDER_DEFINITION* pKFD) {
		CoTaskMemFree(pKFD.pszName);
		CoTaskMemFree(pKFD.pszDescription);
		CoTaskMemFree(pKFD.pszRelativePath);
		CoTaskMemFree(pKFD.pszParsingName);
		CoTaskMemFree(pKFD.pszTooltip);
		CoTaskMemFree(pKFD.pszLocalizedName);
		CoTaskMemFree(pKFD.pszIcon);
		CoTaskMemFree(pKFD.pszSecurity);
	}

	enum {
		SHARE_ROLE_INVALID     = -1,
		SHARE_ROLE_READER      = 0,
		SHARE_ROLE_CONTRIBUTOR = 1,
		SHARE_ROLE_CO_OWNER    = 2,
		SHARE_ROLE_OWNER       = 3,
		SHARE_ROLE_CUSTOM      = 4,
		SHARE_ROLE_MIXED       = 5
	}
	alias int SHARE_ROLE;

	enum {
		DEFSHAREID_USERS  = 1,
		DEFSHAREID_PUBLIC = 2
	}
	alias int DEF_SHARE_ID;

	//extern extern(C) const IID IID_ISharingConfigurationManager;
	interface ISharingConfigurationManager : IUnknown {
	public extern(Windows):
		HRESULT CreateShare(DEF_SHARE_ID dsid, SHARE_ROLE role);
		HRESULT DeleteShare(DEF_SHARE_ID dsid);
		HRESULT ShareExists(DEF_SHARE_ID dsid);
		HRESULT GetSharePermissions(DEF_SHARE_ID dsid, SHARE_ROLE* pRole);
		HRESULT SharePrinters();
		HRESULT StopSharingPrinters();
		HRESULT ArePrintersShared();
	}
	mixin DEFINE_IID!(ISharingConfigurationManager, "B4CD448A-9C86-4466-9201-2E62105B87AE");

//extern extern(C) const IID IID_IPreviousVersionsInfo;
interface IPreviousVersionsInfo : IUnknown {
public extern(Windows):
	HRESULT AreSnapshotsAvailable(LPCWSTR pszPath, BOOL fOkToBeSlow, BOOL* pfAvailable);
}
mixin DEFINE_IID!(IPreviousVersionsInfo, "76e54780-ad74-48e3-a695-3ba9a0aff10d");

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_IRelatedItem;
	interface IRelatedItem : IUnknown {
	public extern(Windows):
		HRESULT GetItemIDList(PIDLIST_ABSOLUTE* ppidl);
		HRESULT GetItem(IShellItem* ppsi);
	}
	mixin DEFINE_IID!(IRelatedItem, "a73ce67a-8ab1-44f1-8d43-d2fcbf6b1cd0");

	//extern extern(C) const IID IID_IIdentityName;
	interface IIdentityName : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(IIdentityName, "7d903fca-d6f9-4810-8332-946c0177e247");

	//extern extern(C) const IID IID_IDelegateItem;
	interface IDelegateItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(IDelegateItem, "3c5a1c94-c951-4cb7-bb6d-3b93f30cce93");

	//extern extern(C) const IID IID_ICurrentItem;
	interface ICurrentItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(ICurrentItem, "240a7174-d653-4a1d-a6d3-d4943cfbfe3d");

	//extern extern(C) const IID IID_ITransferMediumItem;
	interface ITransferMediumItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(ITransferMediumItem, "77f295d5-2d6f-4e19-b8ae-322f3e721ab5");

	//extern extern(C) const IID IID_IUseToBrowseItem;
	interface IUseToBrowseItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(IUseToBrowseItem, "05edda5c-98a3-4717-8adb-c5e7da991eb1");

	//extern extern(C) const IID IID_IDisplayItem;
	interface IDisplayItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(IDisplayItem, "c6fd5997-9f6b-4888-8703-94e80e8cde3f");

	//extern extern(C) const IID IID_IViewStateIdentityItem;
	interface IViewStateIdentityItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(IViewStateIdentityItem, "9D264146-A94F-4195-9F9F-3BB12CE0C955");

	//extern extern(C) const IID IID_IPreviewItem;
	interface IPreviewItem : IRelatedItem {
	public extern(Windows):
	}
	mixin DEFINE_IID!(IPreviewItem, "36149969-0A8F-49c8-8B00-4AECB20222FB");

//extern extern(C) const IID IID_IDestinationStreamFactory;
interface IDestinationStreamFactory : IUnknown {
public extern(Windows):
	HRESULT GetDestinationStream(IStream* ppstm);
}
mixin DEFINE_IID!(IDestinationStreamFactory, "8a87781b-39a7-4a1f-aab3-a39b9c34a7d9");

enum {
	NMCII_ITEMS   = 0x1,
	NMCII_FOLDERS = 0x2
}
alias int NMCII_FLAGS;

enum {
	NMCSAEI_SELECT = 0,
	NMCSAEI_EDIT   = 0x1
}
alias int NMCSAEI_FLAGS;

//extern extern(C) const IID IID_INewMenuClient;
interface INewMenuClient : IUnknown {
public extern(Windows):
	HRESULT IncludeItems(NMCII_FLAGS* pflags);
	HRESULT SelectAndEditItem(PCIDLIST_ABSOLUTE pidlItem, NMCSAEI_FLAGS flags);
}
mixin DEFINE_IID!(INewMenuClient, "dcb07fdc-3bb5-451c-90be-966644fed7b0");
alias IID_INewMenuClient SID_SNewMenuClient;

mixin DEFINE_GUID!("SID_SCommandBarState", 0xB99EAA5C, 0x3850, 0x4400, 0xBC, 0x33, 0x2C, 0xE5, 0x34, 0x04, 0x8B, 0xF8);

//(_WIN32_IE >= _WIN32_IE_IE70)
	//extern extern(C) const IID IID_IInitializeWithBindCtx;
	interface IInitializeWithBindCtx : IUnknown {
	public extern(Windows):
		HRESULT Initialize(IBindCtx pbc);
	}
	mixin DEFINE_IID!(IInitializeWithBindCtx, "71c0d2bc-726d-45cc-a6c0-2e31c1db2159");

	//extern extern(C) const IID IID_IShellItemFilter;
	interface IShellItemFilter : IUnknown {
	public extern(Windows):
		HRESULT IncludeItem(IShellItem psi);
		HRESULT GetEnumFlagsForItem(IShellItem psi, SHCONTF* pgrfFlags);
	}
	mixin DEFINE_IID!(IShellItemFilter, "2659B475-EEB8-48b7-8F07-B378810F48CF");

enum {
	NSTCS_HASEXPANDOS         = 0x1,
	NSTCS_HASLINES            = 0x2,
	NSTCS_SINGLECLICKEXPAND   = 0x4,
	NSTCS_FULLROWSELECT       = 0x8,
	NSTCS_SPRINGEXPAND        = 0x10,
	NSTCS_HORIZONTALSCROLL    = 0x20,
	NSTCS_ROOTHASEXPANDO      = 0x40,
	NSTCS_SHOWSELECTIONALWAYS = 0x80,
	NSTCS_NOINFOTIP           = 0x200,
	NSTCS_EVENHEIGHT          = 0x400,
	NSTCS_NOREPLACEOPEN       = 0x800,
	NSTCS_DISABLEDRAGDROP     = 0x1000,
	NSTCS_NOORDERSTREAM       = 0x2000,
	NSTCS_RICHTOOLTIP         = 0x4000,
	NSTCS_BORDER              = 0x8000,
	NSTCS_NOEDITLABELS        = 0x10000,
	NSTCS_TABSTOP             = 0x20000,
	NSTCS_FAVORITESMODE       = 0x80000,
	NSTCS_AUTOHSCROLL         = 0x100000,
	NSTCS_FADEINOUTEXPANDOS   = 0x200000,
	NSTCS_EMPTYTEXT           = 0x400000,
	NSTCS_CHECKBOXES          = 0x800000,
	NSTCS_PARTIALCHECKBOXES   = 0x1000000,
	NSTCS_EXCLUSIONCHECKBOXES = 0x2000000,
	NSTCS_DIMMEDCHECKBOXES    = 0x4000000,
	NSTCS_NOINDENTCHECKS      = 0x8000000,
	NSTCS_ALLOWJUNCTIONS      = 0x10000000,
	NSTCS_SHOWTABSBUTTON      = 0x20000000,
	NSTCS_SHOWDELETEBUTTON    = 0x40000000,
	NSTCS_SHOWREFRESHBUTTON   = cast(int)0x80000000
}
alias DWORD NSTCSTYLE;

enum {
	NSTCRS_VISIBLE  = 0,
	NSTCRS_HIDDEN   = 0x1,
	NSTCRS_EXPANDED = 0x2
}
alias DWORD NSTCROOTSTYLE;

enum {
	NSTCIS_NONE             = 0,
	NSTCIS_SELECTED         = 0x1,
	NSTCIS_EXPANDED         = 0x2,
	NSTCIS_BOLD             = 0x4,
	NSTCIS_DISABLED         = 0x8,
	NSTCIS_SELECTEDNOEXPAND = 0x10
}
alias DWORD NSTCITEMSTATE;

enum {
	NSTCGNI_NEXT         = 0,
	NSTCGNI_NEXTVISIBLE  = 1,
	NSTCGNI_PREV         = 2,
	NSTCGNI_PREVVISIBLE  = 3,
	NSTCGNI_PARENT       = 4,
	NSTCGNI_CHILD        = 5,
	NSTCGNI_FIRSTVISIBLE = 6,
	NSTCGNI_LASTVISIBLE  = 7
}
alias int NSTCGNI;

//extern extern(C) const IID IID_INameSpaceTreeControl;
interface INameSpaceTreeControl : IUnknown {
public extern(Windows):
	HRESULT Initialize(HWND hwndParent, RECT* prc, NSTCSTYLE nsctsFlags);
	HRESULT TreeAdvise(IUnknown punk, DWORD* pdwCookie);
	HRESULT TreeUnadvise(DWORD dwCookie);
	HRESULT AppendRoot(IShellItem psiRoot, SHCONTF grfEnumFlags, NSTCROOTSTYLE grfRootStyle, IShellItemFilter pif);
	HRESULT InsertRoot(int iIndex, IShellItem psiRoot, SHCONTF grfEnumFlags, NSTCROOTSTYLE grfRootStyle, IShellItemFilter pif);
	HRESULT RemoveRoot(IShellItem psiRoot);
	HRESULT RemoveAllRoots();
	HRESULT GetRootItems(IShellItemArray* ppsiaRootItems);
	HRESULT SetItemState(IShellItem psi, NSTCITEMSTATE nstcisMask, NSTCITEMSTATE nstcisFlags);
	HRESULT GetItemState(IShellItem psi, NSTCITEMSTATE nstcisMask, NSTCITEMSTATE* pnstcisFlags);
	HRESULT GetSelectedItems(IShellItemArray* psiaItems);
	HRESULT GetItemCustomState(IShellItem psi, int* piStateNumber);
	HRESULT SetItemCustomState(IShellItem psi, int iStateNumber);
	HRESULT EnsureItemVisible(IShellItem psi);
	HRESULT SetTheme(LPCWSTR pszTheme);
	HRESULT GetNextItem(IShellItem psi, NSTCGNI nstcgi, IShellItem* ppsiNext);
	HRESULT HitTest(POINT* ppt, IShellItem* ppsiOut);
	HRESULT GetItemRect(IShellItem psi, RECT* prect);
	HRESULT CollapseAll();
}
mixin DEFINE_IID!(INameSpaceTreeControl, "028212A3-B627-47e9-8856-C14265554E4F");

enum {
	NSTCS2_DEFAULT                  = 0,
	NSTCS2_INTERRUPTNOTIFICATIONS   = 0x1,
	NSTCS2_SHOWNULLSPACEMENU        = 0x2,
	NSTCS2_DISPLAYPADDING           = 0x4,
	NSTCS2_DISPLAYPINNEDONLY        = 0x8,
	NTSCS2_NOSINGLETONAUTOEXPAND    = 0x10,
	NTSCS2_NEVERINSERTNONENUMERATED = 0x20
}
alias int NSTCSTYLE2;

//extern extern(C) const IID IID_INameSpaceTreeControl2;
interface INameSpaceTreeControl2 : INameSpaceTreeControl {
public extern(Windows):
	HRESULT SetControlStyle(NSTCSTYLE nstcsMask, NSTCSTYLE nstcsStyle);
	HRESULT GetControlStyle(NSTCSTYLE nstcsMask, NSTCSTYLE* pnstcsStyle);
	HRESULT SetControlStyle2(NSTCSTYLE2 nstcsMask, NSTCSTYLE2 nstcsStyle);
	HRESULT GetControlStyle2(NSTCSTYLE2 nstcsMask, NSTCSTYLE2* pnstcsStyle);
}
mixin DEFINE_IID!(INameSpaceTreeControl2, "7cc7aed8-290e-49bc-8945-c1401cc9306c");

enum NSTCS2_ALLMASK = NSTCS2_INTERRUPTNOTIFICATIONS | NSTCS2_SHOWNULLSPACEMENU | NSTCS2_DISPLAYPADDING;
alias IID_INameSpaceTreeControl SID_SNavigationPane;

/*
	ISLBUTTON(x) (NSTCECT_LBUTTON == ((x) & NSTCECT_BUTTON))
	ISMBUTTON(x) (NSTCECT_MBUTTON == ((x) & NSTCECT_BUTTON))
	ISRBUTTON(x) (NSTCECT_RBUTTON == ((x) & NSTCECT_BUTTON))
	ISDBLCLICK(x) (NSTCECT_DBLCLICK == ((x) & NSTCECT_DBLCLICK))
*/

enum {
	NSTCEHT_NOWHERE         = 0x1,
	NSTCEHT_ONITEMICON      = 0x2,
	NSTCEHT_ONITEMLABEL     = 0x4,
	NSTCEHT_ONITEMINDENT    = 0x8,
	NSTCEHT_ONITEMBUTTON    = 0x10,
	NSTCEHT_ONITEMRIGHT     = 0x20,
	NSTCEHT_ONITEMSTATEICON = 0x40,
	NSTCEHT_ONITEM          = 0x46,
	NSTCEHT_ONITEMTABBUTTON = 0x1000
}
alias DWORD NSTCEHITTEST;

enum {
	NSTCECT_LBUTTON  = 0x1,
	NSTCECT_MBUTTON  = 0x2,
	NSTCECT_RBUTTON  = 0x3,
	NSTCECT_BUTTON   = 0x3,
	NSTCECT_DBLCLICK = 0x4
}
alias DWORD NSTCECLICKTYPE;

//extern extern(C) const IID IID_INameSpaceTreeControlEvents;
interface INameSpaceTreeControlEvents : IUnknown {
public extern(Windows):
	HRESULT OnItemClick(IShellItem psi, NSTCEHITTEST nstceHitTest, NSTCECLICKTYPE nstceClickType);
	HRESULT OnPropertyItemCommit(IShellItem psi);
	HRESULT OnItemStateChanging(IShellItem psi, NSTCITEMSTATE nstcisMask, NSTCITEMSTATE nstcisState);
	HRESULT OnItemStateChanged(IShellItem psi, NSTCITEMSTATE nstcisMask, NSTCITEMSTATE nstcisState);
	HRESULT OnSelectionChanged(IShellItemArray psiaSelection);
	HRESULT OnKeyboardInput(UINT uMsg, WPARAM wParam, LPARAM lParam);
	HRESULT OnBeforeExpand(IShellItem psi);
	HRESULT OnAfterExpand(IShellItem psi);
	HRESULT OnBeginLabelEdit(IShellItem psi);
	HRESULT OnEndLabelEdit(IShellItem psi);
	HRESULT OnGetToolTip(IShellItem psi, LPWSTR pszTip, int cchTip);
	HRESULT OnBeforeItemDelete(IShellItem psi);
	HRESULT OnItemAdded(IShellItem psi, BOOL fIsRoot);
	HRESULT OnItemDeleted(IShellItem psi, BOOL fIsRoot);
	HRESULT OnBeforeContextMenu(IShellItem psi, REFIID riid, void** ppv);
	HRESULT OnAfterContextMenu(IShellItem psi, IContextMenu pcmIn, REFIID riid, void** ppv);
	HRESULT OnBeforeStateImageChange(IShellItem psi);
	HRESULT OnGetDefaultIconIndex(IShellItem psi, int* piDefaultIcon, int* piOpenIcon);
}
mixin DEFINE_IID!(INameSpaceTreeControlEvents, "93D77985-B3D8-4484-8318-672CDDA002CE");

enum NSTCDHPOS_ONTOP = -1;

//extern extern(C) const IID IID_INameSpaceTreeControlDropHandler;
interface INameSpaceTreeControlDropHandler : IUnknown {
public extern(Windows):
	HRESULT OnDragEnter(IShellItem psiOver, IShellItemArray psiaData, BOOL fOutsideSource, DWORD grfKeyState, DWORD* pdwEffect);
	HRESULT OnDragOver(IShellItem psiOver, IShellItemArray psiaData, DWORD grfKeyState, DWORD* pdwEffect);
	HRESULT OnDragPosition(IShellItem psiOver, IShellItemArray psiaData, int iNewPosition, int iOldPosition);
	HRESULT OnDrop(IShellItem psiOver, IShellItemArray psiaData, int iPosition, DWORD grfKeyState, DWORD* pdwEffect);
	HRESULT OnDropPosition(IShellItem psiOver, IShellItemArray psiaData, int iNewPosition, int iOldPosition);
	HRESULT OnDragLeave(IShellItem psiOver);
}
mixin DEFINE_IID!(INameSpaceTreeControlDropHandler, "F9C665D6-C2F2-4c19-BF33-8322D7352F51");

//extern extern(C) const IID IID_INameSpaceTreeAccessible;
interface INameSpaceTreeAccessible : IUnknown {
public extern(Windows):
	HRESULT OnGetDefaultAccessibilityAction(IShellItem psi, BSTR* pbstrDefaultAction);
	HRESULT OnDoDefaultAccessibilityAction(IShellItem psi);
	HRESULT OnGetAccessibilityRole(IShellItem psi, VARIANT* pvarRole);
}
mixin DEFINE_IID!(INameSpaceTreeAccessible, "71f312de-43ed-4190-8477-e9536b82350b");

struct NSTCCUSTOMDRAW {
	IShellItem psi;
	UINT uItemState;
	NSTCITEMSTATE nstcis;
	LPCWSTR pszText;
	int iImage;
	HIMAGELIST himl;
	int iLevel;
	int iIndent;
}

//extern extern(C) const IID IID_INameSpaceTreeControlCustomDraw;
interface INameSpaceTreeControlCustomDraw : IUnknown {
public extern(Windows):
	HRESULT PrePaint(HDC hdc, RECT* prc, LRESULT* plres);
	HRESULT PostPaint(HDC hdc, RECT* prc);
	HRESULT ItemPrePaint(HDC hdc, RECT* prc, NSTCCUSTOMDRAW* pnstccdItem, COLORREF* pclrText, COLORREF* pclrTextBk, LRESULT* plres);
	HRESULT ItemPostPaint(HDC hdc, RECT* prc, NSTCCUSTOMDRAW* pnstccdItem);
}
mixin DEFINE_IID!(INameSpaceTreeControlCustomDraw, "2D3BA758-33EE-42d5-BB7B-5F3431D86C78");

//(NTDDI_VERSION >= NTDDI_VISTA)
	enum {
		NSTCFC_NONE                  = 0,
		NSTCFC_PINNEDITEMFILTERING   = 0x1,
		NSTCFC_DELAY_REGISTER_NOTIFY = 0x2
	}
	alias int NSTCFOLDERCAPABILITIES;

	//extern extern(C) const IID IID_INameSpaceTreeControlFolderCapabilities;
	interface INameSpaceTreeControlFolderCapabilities : IUnknown {
	public extern(Windows):
		HRESULT GetFolderCapabilities(NSTCFOLDERCAPABILITIES nfcMask, NSTCFOLDERCAPABILITIES* pnfcValue);
	}
	mixin DEFINE_IID!(INameSpaceTreeControlFolderCapabilities, "e9701183-e6b3-4ff2-8568-813615fec7be");

enum {
	E_PREVIEWHANDLER_DRM_FAIL = cast(HRESULT)0x86420001,
	E_PREVIEWHANDLER_NOAUTH   = cast(HRESULT)0x86420002,
	E_PREVIEWHANDLER_NOTFOUND = cast(HRESULT)0x86420003,
	E_PREVIEWHANDLER_CORRUPT  = cast(HRESULT)0x86420004,
}

//extern extern(C) const IID IID_IPreviewHandler;
interface IPreviewHandler : IUnknown {
public extern(Windows):
	HRESULT SetWindow(HWND hwnd, const(RECT)* prc);
	HRESULT SetRect(const(RECT)* prc);
	HRESULT DoPreview();
	HRESULT Unload();
	HRESULT SetFocus();
	HRESULT QueryFocus(HWND* phwnd);
	HRESULT TranslateAccelerator(MSG* pmsg);
}
mixin DEFINE_IID!(IPreviewHandler, "8895b1c6-b41f-4c1c-a562-0d564250836f");

struct PREVIEWHANDLERFRAMEINFO {
	HACCEL haccel;
	UINT cAccelEntries;
}

//extern extern(C) const IID IID_IPreviewHandlerFrame;
interface IPreviewHandlerFrame : IUnknown {
public extern(Windows):
	HRESULT GetWindowContext(PREVIEWHANDLERFRAMEINFO* pinfo);
	HRESULT TranslateAccelerator(MSG* pmsg);
}
mixin DEFINE_IID!(IPreviewHandlerFrame, "fec87aaf-35f9-447a-adb7-20234491401a");

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_ITrayDeskBand;
	interface ITrayDeskBand : IUnknown {
	public extern(Windows):
		HRESULT ShowDeskBand(REFCLSID clsid);
		HRESULT HideDeskBand(REFCLSID clsid);
		HRESULT IsDeskBandShown(REFCLSID clsid);
		HRESULT DeskBandRegistrationChanged();
	}
	mixin DEFINE_IID!(ITrayDeskBand, "6D67E846-5B9C-4db8-9CBC-DDE12F4254F1");

	//extern extern(C) const IID IID_IBandHost;
	interface IBandHost : IUnknown {
	public extern(Windows):
		HRESULT CreateBand(REFCLSID rclsidBand, BOOL fAvailable, BOOL fVisible, REFIID riid, void** ppv);
		HRESULT SetBandAvailability(REFCLSID rclsidBand, BOOL fAvailable);
		HRESULT DestroyBand(REFCLSID rclsidBand);
	}
	mixin DEFINE_IID!(IBandHost, "B9075C7C-D48E-403f-AB99-D6C77A1084AC");
	alias IID_IBandHost SID_SBandHost;
	alias GUID EXPLORERPANE;

	alias const(EXPLORERPANE)* REFEXPLORERPANE;

	enum {
		EPS_DONTCARE     = 0,
		EPS_DEFAULT_ON   = 0x1,
		EPS_DEFAULT_OFF  = 0x2,
		EPS_STATEMASK    = 0xffff,
		EPS_INITIALSTATE = 0x10000,
		EPS_FORCE        = 0x20000
	}
	alias DWORD EXPLORERPANESTATE;

	//extern extern(C) const IID IID_IExplorerPaneVisibility;
	interface IExplorerPaneVisibility : IUnknown {
	public extern(Windows):
		HRESULT GetPaneState(REFEXPLORERPANE ep, EXPLORERPANESTATE* peps);
	}
	mixin DEFINE_IID!(IExplorerPaneVisibility, "e07010ec-bc17-44c0-97b0-46c7c95b9edc");
	alias IID_IExplorerPaneVisibility SID_ExplorerPaneVisibility;

	//extern extern(C) const IID IID_IContextMenuCB;
	interface IContextMenuCB : IUnknown {
	public extern(Windows):
		HRESULT CallBack(IShellFolder psf, HWND hwndOwner, IDataObject pdtobj, UINT uMsg, WPARAM wParam, LPARAM lParam);
	}
	mixin DEFINE_IID!(IContextMenuCB, "3409E930-5A39-11d1-83FA-00A0C90DC849");

	//extern extern(C) const IID IID_IDefaultExtractIconInit;
	interface IDefaultExtractIconInit : IUnknown {
	public extern(Windows):
		HRESULT SetFlags(UINT uFlags);
		HRESULT SetKey(HKEY hkey);
		HRESULT SetNormalIcon(LPCWSTR pszFile, int iIcon);
		HRESULT SetOpenIcon(LPCWSTR pszFile, int iIcon);
		HRESULT SetShortcutIcon(LPCWSTR pszFile, int iIcon);
		HRESULT SetDefaultIcon(LPCWSTR pszFile, int iIcon);
	}
	mixin DEFINE_IID!(IDefaultExtractIconInit, "41ded17d-d6b3-4261-997d-88c60e4b1d58");

static if(NTDDI_VERSION >= NTDDI_VISTA){
	export extern(Windows) HRESULT SHCreateDefaultExtractIcon(REFIID riid, void** ppv);
}

enum {
	ECS_ENABLED    = 0,
	ECS_DISABLED   = 0x1,
	ECS_HIDDEN     = 0x2,
	ECS_CHECKBOX   = 0x4,
	ECS_CHECKED    = 0x8,
	ECS_RADIOCHECK = 0x10
}
alias DWORD EXPCMDSTATE;

enum {
	ECF_DEFAULT         = 0,
	ECF_HASSUBCOMMANDS  = 0x1,
	ECF_HASSPLITBUTTON  = 0x2,
	ECF_HIDELABEL       = 0x4,
	ECF_ISSEPARATOR     = 0x8,
	ECF_HASLUASHIELD    = 0x10,
	ECF_SEPARATORBEFORE = 0x20,
	ECF_SEPARATORAFTER  = 0x40,
	ECF_ISDROPDOWN      = 0x80
}
alias DWORD EXPCMDFLAGS;

//extern extern(C) const IID IID_IExplorerCommand;
interface IExplorerCommand : IUnknown {
public extern(Windows):
	HRESULT GetTitle(IShellItemArray psiItemArray, LPWSTR* ppszName);
	HRESULT GetIcon(IShellItemArray psiItemArray, LPWSTR* ppszIcon);
	HRESULT GetToolTip(IShellItemArray psiItemArray, LPWSTR* ppszInfotip);
	HRESULT GetCanonicalName(GUID* pguidCommandName);
	HRESULT GetState(IShellItemArray psiItemArray, BOOL fOkToBeSlow, EXPCMDSTATE* pCmdState);
	HRESULT Invoke(IShellItemArray psiItemArray, IBindCtx pbc);
	HRESULT GetFlags(EXPCMDFLAGS* pFlags);
	HRESULT EnumSubCommands(IEnumExplorerCommand* ppEnum);
}
mixin DEFINE_IID!(IExplorerCommand, "a08ce4d0-fa25-44ab-b57c-c7b1c323e0b9");

//extern extern(C) const IID IID_IExplorerCommandState;
interface IExplorerCommandState : IUnknown {
public extern(Windows):
	HRESULT GetState(IShellItemArray psiItemArray, BOOL fOkToBeSlow, EXPCMDSTATE* pCmdState);
}
mixin DEFINE_IID!(IExplorerCommandState, "bddacb60-7657-47ae-8445-d23e1acf82ae");

//extern extern(C) const IID IID_IInitializeCommand;
interface IInitializeCommand : IUnknown {
public extern(Windows):
	HRESULT Initialize(LPCWSTR pszCommandName, IPropertyBag ppb);
}
mixin DEFINE_IID!(IInitializeCommand, "85075acf-231f-40ea-9610-d26b7b58f638");

//extern extern(C) const IID IID_IEnumExplorerCommand;
interface IEnumExplorerCommand : IUnknown {
public extern(Windows):
	HRESULT Next(ULONG celt, IExplorerCommand* pUICommand, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumExplorerCommand* ppenum);
}
mixin DEFINE_IID!(IEnumExplorerCommand, "a88826f8-186f-4987-aade-ea0cef8fbfe8");

export extern(Windows){
	HRESULT IEnumExplorerCommand_RemoteNext_Proxy(IEnumExplorerCommand This, ULONG celt, IExplorerCommand* pUICommand, ULONG* pceltFetched);
	void IEnumExplorerCommand_RemoteNext_Stub(IRpcStubBuffer This, IRpcChannelBuffer _pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD* _pdwStubPhase);
}

//extern extern(C) const IID IID_IExplorerCommandProvider;
mixin DEFINE_GUID!(IExplorerCommandProvider, "64961751-0835-43c0-8ffe-d57686530e64");
interface IExplorerCommandProvider : IUnknown {
public extern(Windows):
	HRESULT GetCommands(IUnknown punkSite, REFIID riid, void** ppv);
	HRESULT GetCommand(REFGUID rguidCommandId, REFIID riid, void** ppv);
}

//extern extern(C) const IID IID_IMarkupCallback;
interface IMarkupCallback : IUnknown {
public extern(Windows):
	HRESULT GetState(DWORD dwId, UINT uState);
	HRESULT Notify(DWORD dwId, int nCode, int iLink);
	HRESULT InvalidateRect(DWORD dwId, const(RECT)* prc);
	HRESULT OnCustomDraw(DWORD dwDrawStage, HDC hdc, const(RECT)* prc, DWORD dwId, int iLink, UINT uItemState, LRESULT* pdwResult);
	HRESULT CustomDrawText(HDC hDC, LPCWSTR lpString, int nCount, RECT* pRect, UINT uFormat, BOOL fLink);
}
mixin DEFINE_IID!(IMarkupCallback, "4440306e-d79a-48d0-88e6-a42692279bfb");

enum HTHEME : HANDLE {init = (HANDLE).init}

enum {
	MARKUPSIZE_CALCWIDTH,
	MARKUPSIZE_CALCHEIGHT,
}
alias int MARKUPSIZE;

enum {
	MARKUPLINKTEXT_URL,
	MARKUPLINKTEXT_ID,
	MARKUPLINKTEXT_TEXT,
}
alias int MARKUPLINKTEXT;

enum {
	MARKUPSTATE_FOCUSED       = 0x1,
	MARKUPSTATE_ENABLED       = 0x2,
	MARKUPSTATE_VISITED       = 0x4,
	MARKUPSTATE_HOT           = 0x8,
	MARKUPSTATE_DEFAULTCOLORS = 0x10,
	MARKUPSTATE_ALLOWMARKUP   = 0x40000000
}
alias DWORD MARKUPSTATE;

enum {
	MARKUPMESSAGE_KEYEXECUTE,
	MARKUPMESSAGE_CLICKEXECUTE,
	MARKUPMESSAGE_WANTFOCUS,
}
alias int MARKUPMESSAGE;

//extern extern(C) const IID IID_IControlMarkup;
interface IControlMarkup : IUnknown {
public extern(Windows):
	HRESULT SetCallback(IUnknown punk);
	HRESULT GetCallback(REFIID riid, void** ppvUnk);
	HRESULT SetId(DWORD dwId);
	HRESULT GetId(DWORD* pdwId);
	HRESULT SetFonts(HFONT hFont, HFONT hFontUnderline);
	HRESULT GetFonts(HFONT* phFont, HFONT* phFontUnderline);
	HRESULT SetText(LPCWSTR pwszText);
	HRESULT GetText(BOOL bRaw, LPWSTR pwszText, DWORD* pdwCch);
	HRESULT SetLinkText(int iLink, UINT uMarkupLinkText, LPCWSTR pwszText);
	HRESULT GetLinkText(int iLink, UINT uMarkupLinkText, LPWSTR pwszText, DWORD* pdwCch);
	HRESULT SetRenderFlags(UINT uDT);
	HRESULT GetRenderFlags(UINT* puDT, HTHEME* phTheme, int* piPartId, int* piStateIdNormal, int* piStateIdLink);
	HRESULT SetThemeRenderFlags(UINT uDT, HTHEME hTheme, int iPartId, int iStateIdNormal, int iStateIdLink);
	HRESULT GetState(int iLink, UINT uStateMask, UINT* puState);
	HRESULT SetState(int iLink, UINT uStateMask, UINT uState);
	HRESULT DrawText(HDC hdcClient, LPCRECT prcClient);
	HRESULT SetLinkCursor();
	HRESULT CalcIdealSize(HDC hdc, UINT uMarkUpCalc, RECT* prc);
	HRESULT SetFocus();
	HRESULT KillFocus();
	HRESULT IsTabbable();
	HRESULT OnButtonDown(POINT pt);
	HRESULT OnButtonUp(POINT pt);
	HRESULT OnKeyDown(UINT uVirtKey);
	HRESULT HitTest(POINT pt, int* piLink);
	HRESULT GetLinkRect(int iLink, RECT* prc);
	HRESULT GetControlRect(RECT* prcControl);
	HRESULT GetLinkCount(UINT* pcLinks);
}
mixin DEFINE_IID!(IControlMarkup, "D6D2FBAE-F116-458c-8C34-03569877A2D2");

//extern extern(C) const IID IID_IInitializeNetworkFolder;
interface IInitializeNetworkFolder : IUnknown {
public extern(Windows):
	HRESULT Initialize(PCIDLIST_ABSOLUTE pidl, PCIDLIST_ABSOLUTE pidlTarget, UINT uDisplayType, LPCWSTR pszResName, LPCWSTR pszProvider);
}
mixin DEFINE_IID!(IInitializeNetworkFolder, "6e0f9881-42a8-4f2a-97f8-8af4e026d92d");

enum {
	CPVIEW_CLASSIC  = 0,
	CPVIEW_ALLITEMS = CPVIEW_CLASSIC,
	CPVIEW_CATEGORY = 1,
	CPVIEW_HOME     = CPVIEW_CATEGORY
}
alias int CPVIEW;

//extern extern(C) const IID IID_IOpenControlPanel;
interface IOpenControlPanel : IUnknown {
public extern(Windows):
	HRESULT Open(LPCWSTR pszName, LPCWSTR pszPage, IUnknown punkSite);
	HRESULT GetPath(LPCWSTR pszName, LPWSTR pszPath, UINT cchPath);
	HRESULT GetCurrentView(CPVIEW* pView);
}
mixin DEFINE_IID!(IOpenControlPanel, "D11AD862-66DE-4DF4-BF6C-1F5621996AF1");

//extern extern(C) const IID IID_IComputerInfoChangeNotify;
interface IComputerInfoChangeNotify : IUnknown {
public extern(Windows):
	HRESULT ComputerInfoChanged();
}
mixin DEFINE_IID!(IComputerInfoChangeNotify, "0DF60D92-6818-46d6-B358-D66170DDE466");
const wchar* STR_FILE_SYS_BIND_DATA = "File System Bind Data";

//extern extern(C) const IID IID_IFileSystemBindData;
interface IFileSystemBindData : IUnknown {
public extern(Windows):
	HRESULT SetFindData(const(WIN32_FIND_DATAW)* pfd);
	HRESULT GetFindData(WIN32_FIND_DATAW* pfd);
}
mixin DEFINE_IID!(IFileSystemBindData, "01E18D10-4D8B-11d2-855D-006008059367");

//extern extern(C) const IID IID_IFileSystemBindData2;
interface IFileSystemBindData2 : IFileSystemBindData {
public extern(Windows):
	HRESULT SetFileID(LARGE_INTEGER liFileID);
	HRESULT GetFileID(LARGE_INTEGER* pliFileID);
	HRESULT SetJunctionCLSID(REFCLSID clsid);
	HRESULT GetJunctionCLSID(CLSID* pclsid);
}
mixin DEFINE_IID!(IFileSystemBindData2, "3acf075f-71db-4afa-81f0-3fc4fdf2a5b8");

//(NTDDI_VERSION >= NTDDI_WIN7)
	enum {
		KDC_FREQUENT = 1,
		KDC_RECENT,
	}
	alias int KNOWNDESTCATEGORY;

	//extern extern(C) const IID IID_ICustomDestinationList;
	interface ICustomDestinationList : IUnknown {
	public extern(Windows):
		HRESULT SetAppID(LPCWSTR pszAppID);
		HRESULT BeginList(UINT* pcMinSlots, REFIID riid, void** ppv);
		HRESULT AppendCategory(LPCWSTR pszCategory, IObjectArray poa);
		HRESULT AppendKnownCategory(KNOWNDESTCATEGORY category);
		HRESULT AddUserTasks(IObjectArray poa);
		HRESULT CommitList();
		HRESULT GetRemovedDestinations(REFIID riid, void** ppv);
		HRESULT DeleteList(LPCWSTR pszAppID);
		HRESULT AbortList();
	}
	mixin DEFINE_IID!(ICustomDestinationList, "6332debf-87b5-4670-90c0-5e57b408a49e");

	//extern extern(C) const IID IID_IApplicationDestinations;
	interface IApplicationDestinations : IUnknown {
	public extern(Windows):
		HRESULT SetAppID(LPCWSTR pszAppID);
		HRESULT RemoveDestination(IUnknown punk);
		HRESULT RemoveAllDestinations();
	}
	mixin DEFINE_IID!(IApplicationDestinations, "12337d35-94c6-48a0-bce7-6a9c69d4d600");

	enum {
		ADLT_RECENT,
		ADLT_FREQUENT
	}
	alias int APPDOCLISTTYPE;

	//extern extern(C) const IID IID_IApplicationDocumentLists;
	interface IApplicationDocumentLists : IUnknown {
	public extern(Windows):
		HRESULT SetAppID(LPCWSTR pszAppID);
		HRESULT GetList(APPDOCLISTTYPE listtype, UINT cItemsDesired, REFIID riid, void** ppv);
	}
	mixin DEFINE_IID!(IApplicationDocumentLists, "3c594f9f-9f30-47a1-979a-c9e83d3d0a06");

	//extern extern(C) const IID IID_IObjectWithAppUserModelID;
	interface IObjectWithAppUserModelID : IUnknown {
	public extern(Windows):
		HRESULT SetAppID(LPCWSTR pszAppID);
		HRESULT GetAppID(LPWSTR* ppszAppID);
	}
	mixin DEFINE_IID!(IObjectWithAppUserModelID, "36db0196-9665-46d1-9ba7-d3709eecf9ed");

	//extern extern(C) const IID IID_IObjectWithProgID;
	interface IObjectWithProgID : IUnknown {
	public extern(Windows):
		HRESULT SetProgID(LPCWSTR pszProgID);
		HRESULT GetProgID(LPWSTR* ppszProgID);
	}
	mixin DEFINE_IID!(IObjectWithProgID, "71e806fb-8dee-46fc-bf8c-7748a8a1ae13");

	//extern extern(C) const IID IID_IUpdateIDList;
	interface IUpdateIDList : IUnknown {
	public extern(Windows):
		HRESULT Update(IBindCtx pbc, PCUITEMID_CHILD pidlIn, PITEMID_CHILD* ppidlOut);
	}
	mixin DEFINE_IID!(IUpdateIDList, "6589b6d2-5f8d-4b9e-b7e0-23cdd9717d8c");

static if(NTDDI_VERSION >= NTDDI_WIN7){
	export extern(Windows){
		HRESULT SetCurrentProcessExplicitAppUserModelID(PCWSTR AppID);
		HRESULT GetCurrentProcessExplicitAppUserModelID(PWSTR* AppID);
	}
}

//extern extern(C) const IID IID_IDesktopGadget;
interface IDesktopGadget : IUnknown {
public extern(Windows):
	HRESULT RunGadget(LPCWSTR gadgetPath);
}
mixin DEFINE_IID!(IDesktopGadget, "c1646bc4-f298-4f91-a204-eb2dd1709d1a");

const wchar* HOMEGROUP_SECURITY_GROUP = "HomeUsers";

enum {
	HGSC_NONE             = 0,
	HGSC_MUSICLIBRARY     = 0x1,
	HGSC_PICTURESLIBRARY  = 0x2,
	HGSC_VIDEOSLIBRARY    = 0x4,
	HGSC_DOCUMENTSLIBRARY = 0x8,
	HGSC_PRINTERS         = 0x10
}
alias int HOMEGROUPSHARINGCHOICES;

//extern extern(C) const IID IID_IHomeGroup;
interface IHomeGroup : IUnknown {
public extern(Windows):
	HRESULT IsMember(BOOL* member);
	HRESULT ShowSharingWizard(HWND owner, HOMEGROUPSHARINGCHOICES* sharingchoices);
}
mixin DEFINE_IID!(IHomeGroup, "7a3bd1d9-35a9-4fb3-a467-f48cac35e2d0");

//extern extern(C) const IID IID_IInitializeWithPropertyStore;
interface IInitializeWithPropertyStore : IUnknown {
public extern(Windows):
	HRESULT Initialize(IPropertyStore pps);
}
mixin DEFINE_IID!(IInitializeWithPropertyStore, "C3E12EB5-7D8D-44f8-B6DD-0E77B34D6DE4");

//extern extern(C) const IID IID_IOpenSearchSource;
interface IOpenSearchSource : IUnknown {
public extern(Windows):
	HRESULT GetResults(HWND hwnd, LPCWSTR pszQuery, DWORD dwStartIndex, DWORD dwCount, REFIID riid, void** ppv);
}
mixin DEFINE_IID!(IOpenSearchSource, "F0EE7333-E6FC-479b-9F25-A860C234A38E");

enum {
	LFF_FORCEFILESYSTEM = 1,
	LFF_STORAGEITEMS    = 2,
	LFF_ALLITEMS        = 3
}
alias int LIBRARYFOLDERFILTER;

enum {
	LOF_DEFAULT         = 0,
	LOF_PINNEDTONAVPANE = 0x1,
	LOF_MASK_ALL        = 0x1
}
alias int LIBRARYOPTIONFLAGS;

enum {
	DSFT_DETECT = 1,
	DSFT_PRIVATE,
	DSFT_PUBLIC,
}
alias int DEFAULTSAVEFOLDERTYPE;

enum {
	LSF_FAILIFTHERE      = 0,
	LSF_OVERRIDEEXISTING = 0x1,
	LSF_MAKEUNIQUENAME   = 0x2
}
alias int LIBRARYSAVEFLAGS;


//extern extern(C) const IID IID_IShellLibrary;
interface IShellLibrary : IUnknown {
public extern(Windows):
	HRESULT LoadLibraryFromItem(IShellItem psiLibrary, DWORD grfMode);
	HRESULT LoadLibraryFromKnownFolder(REFKNOWNFOLDERID kfidLibrary, DWORD grfMode);
	HRESULT AddFolder(IShellItem psiLocation);
	HRESULT RemoveFolder(IShellItem psiLocation);
	HRESULT GetFolders(LIBRARYFOLDERFILTER lff, REFIID riid, void** ppv);
	HRESULT ResolveFolder(IShellItem psiFolderToResolve, DWORD dwTimeout, REFIID riid, void** ppv);
	HRESULT GetDefaultSaveFolder(DEFAULTSAVEFOLDERTYPE dsft, REFIID riid, void** ppv);
	HRESULT SetDefaultSaveFolder(DEFAULTSAVEFOLDERTYPE dsft, IShellItem psi);
	HRESULT GetOptions(LIBRARYOPTIONFLAGS* plofOptions);
	HRESULT SetOptions(LIBRARYOPTIONFLAGS lofMask, LIBRARYOPTIONFLAGS lofOptions);
	HRESULT GetFolderType(FOLDERTYPEID* pftid);
	HRESULT SetFolderType(REFFOLDERTYPEID ftid);
	HRESULT GetIcon(LPWSTR* ppszIcon);
	HRESULT SetIcon(LPCWSTR pszIcon);
	HRESULT Commit();
	HRESULT Save(IShellItem psiFolderToSaveIn, LPCWSTR pszLibraryName, LIBRARYSAVEFLAGS lsf, IShellItem* ppsiSavedTo);
	HRESULT SaveInKnownFolder(REFKNOWNFOLDERID kfidToSaveIn, LPCWSTR pszLibraryName, LIBRARYSAVEFLAGS lsf, IShellItem* ppsiSavedTo);
}
mixin DEFINE_IID!(IShellLibrary, "11a66efa-382e-451a-9234-1e0e12ef3085");

//extern extern(C) const IID LIBID_ShellObjects;

//extern extern(C) const CLSID CLSID_ShellDesktop;
mixin DEFINE_GUID!("CLSID_ShellDesktop", "00021400-0000-0000-C000-000000000046");

//extern extern(C) const CLSID CLSID_ShellFSFolder;
mixin DEFINE_GUID!("CLSID_ShellFSFolder",  "F3364BA0-65B9-11CE-A9BA-00AA004AE837");

//extern extern(C) const CLSID CLSID_NetworkPlaces;
mixin DEFINE_GUID!("CLSID_NetworkPlaces", "208D2C60-3AEA-1069-A2D7-08002B30309D");

//extern extern(C) const CLSID CLSID_ShellLink;
mixin DEFINE_GUID!("CLSID_ShellLink", "00021401-0000-0000-C000-000000000046");

//extern extern(C) const CLSID CLSID_QueryCancelAutoPlay;
mixin DEFINE_GUID!("CLSID_QueryCancelAutoPlay", "331F1768-05A9-4ddd-B86E-DAE34DDC998A");

//extern extern(C) const CLSID CLSID_DriveSizeCategorizer;
mixin DEFINE_GUID!("CLSID_DriveSizeCategorizer", "94357B53-CA29-4b78-83AE-E8FE7409134F");

//extern extern(C) const CLSID CLSID_DriveTypeCategorizer;
mixin DEFINE_GUID!("CLSID_DriveTypeCategorizer", "B0A8F3CF-4333-4bab-8873-1CCB1CADA48B");

//extern extern(C) const CLSID CLSID_FreeSpaceCategorizer;
mixin DEFINE_GUID!("CLSID_FreeSpaceCategorizer", "B5607793-24AC-44c7-82E2-831726AA6CB7");

//extern extern(C) const CLSID CLSID_TimeCategorizer;
mixin DEFINE_GUID!("CLSID_TimeCategorizer", "3bb4118f-ddfd-4d30-a348-9fb5d6bf1afe");

//extern extern(C) const CLSID CLSID_SizeCategorizer;
mixin DEFINE_GUID!("CLSID_SizeCategorizer", "55d7b852-f6d1-42f2-aa75-8728a1b2d264");

//extern extern(C) const CLSID CLSID_AlphabeticalCategorizer;
mixin DEFINE_GUID!("CLSID_MergedCategorizer", "3c2654c6-7372-4f6b-b310-55d6128f49d2");

//extern extern(C) const CLSID CLSID_MergedCategorizer;
mixin DEFINE_GUID!("CLSID_MergedCategorizer", "8e827c11-33e7-4bc1-b242-8cd9a1c2b304");

//extern extern(C) const CLSID CLSID_ImageProperties;
mixin DEFINE_GUID!("CLSID_ImageProperties", "7ab770c7-0e23-4d7a-8aa2-19bfad479829");

//extern extern(C) const CLSID CLSID_PropertiesUI;
mixin DEFINE_GUID!("CLSID_PropertiesUI", "d912f8cf-0396-4915-884e-fb425d32943b");

//extern extern(C) const CLSID CLSID_UserNotification;
mixin DEFINE_GUID!("CLSID_UserNotification", "0010890e-8789-413c-adbc-48f5b511b3af");

//extern extern(C) const CLSID CLSID_CDBurn;
mixin DEFINE_GUID!("CLSID_CDBurn", "fbeb8a05-beee-4442-804e-409d6c4515e9");

//extern extern(C) const CLSID CLSID_TaskbarList;
mixin DEFINE_GUID!("CLSID_TaskbarList", "56FDF344-FD6D-11d0-958A-006097C9A090");

//extern extern(C) const CLSID CLSID_StartMenuPin;
mixin DEFINE_GUID!("CLSID_StartMenuPin", "a2a9545d-a0c2-42b4-9708-a0b2badd77c8");

//extern extern(C) const CLSID CLSID_WebWizardHost;
mixin DEFINE_GUID!("CLSID_WebWizardHost", "c827f149-55c1-4d28-935e-57e47caed973");

//extern extern(C) const CLSID CLSID_PublishDropTarget;
mixin DEFINE_GUID!("CLSID_PublishDropTarget", "CC6EEFFB-43F6-46c5-9619-51D571967F7D");

//extern extern(C) const CLSID CLSID_PublishingWizard;
mixin DEFINE_GUID!("CLSID_PublishingWizard", "6b33163c-76a5-4b6c-bf21-45de9cd503a1");
alias CLSID_PublishingWizard SID_PublishingWizard;

//extern extern(C) const CLSID CLSID_InternetPrintOrdering;
mixin DEFINE_GUID!("CLSID_InternetPrintOrdering", "add36aa8-751a-4579-a266-d66f5202ccbb");

//extern extern(C) const CLSID CLSID_FolderViewHost;
mixin DEFINE_GUID!("CLSID_FolderViewHost", "20b1cb23-6968-4eb9-b7d4-a66d00d07cee");

//extern extern(C) const CLSID CLSID_ExplorerBrowser;
mixin DEFINE_GUID!("CLSID_ExplorerBrowser", "71f96385-ddd6-48d3-a0c1-ae06e8b055fb");

//extern extern(C) const CLSID CLSID_ImageRecompress;
mixin DEFINE_GUID!("CLSID_ImageRecompress", "6e33091c-d2f8-4740-b55e-2e11d1477a2c");

//extern extern(C) const CLSID CLSID_TrayBandSiteService;
mixin DEFINE_GUID!("CLSID_TrayBandSiteService", "F60AD0A0-E5E1-45cb-B51A-E15B9F8B2934");

//extern extern(C) const CLSID CLSID_TrayDeskBand;
mixin DEFINE_GUID!("CLSID_TrayDeskBand", "E6442437-6C68-4f52-94DD-2CFED267EFB9");

//extern extern(C) const CLSID CLSID_AttachmentServices;
mixin DEFINE_GUID!("CLSID_AttachmentServices", "4125dd96-e03a-4103-8f70-e0597d803b9c");

//extern extern(C) const CLSID CLSID_DocPropShellExtension;
mixin DEFINE_GUID!("CLSID_DocPropShellExtension", "883373C3-BF89-11D1-BE35-080036B11A03");

//extern extern(C) const CLSID CLSID_ShellItem;
mixin DEFINE_GUID!("CLSID_ShellItem", "9ac9fbe1-e0a2-4ad6-b4ee-e212013ea917");

//extern extern(C) const CLSID CLSID_NamespaceWalker;
mixin DEFINE_GUID!("CLSID_NamespaceWalker", "72eb61e0-8672-4303-9175-f2e4c68b2e7c");

//extern extern(C) const CLSID CLSID_FileOperation;
mixin DEFINE_GUID!("CLSID_FileOperation", "3ad05575-8857-4850-9277-11b85bdb8e09");

//extern extern(C) const CLSID CLSID_FileOpenDialog;
mixin DEFINE_GUID!("CLSID_FileOpenDialog", "DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7");

//extern extern(C) const CLSID CLSID_FileSaveDialog;
mixin DEFINE_GUID!("CLSID_FileSaveDialog", "C0B4E2F3-BA21-4773-8DBA-335EC946EB8B");

//extern extern(C) const CLSID CLSID_KnownFolderManager;
mixin DEFINE_GUID!("CLSID_KnownFolderManager", "4df0c730-df9d-4ae3-9153-aa6b82e9795a");

//extern extern(C) const CLSID CLSID_FSCopyHandler;
mixin DEFINE_GUID!("CLSID_FSCopyHandler", "D197380A-0A79-4dc8-A033-ED882C2FA14B");

//extern extern(C) const CLSID CLSID_SharingConfigurationManager;
mixin DEFINE_GUID!("CLSID_SharingConfigurationManager", "49F371E1-8C5C-4d9c-9A3B-54A6827F513C");

//extern extern(C) const CLSID CLSID_PreviousVersions;
mixin DEFINE_GUID!("CLSID_PreviousVersions", "596AB062-B4D2-4215-9F74-E9109B0A8153");

//extern extern(C) const CLSID CLSID_NetworkConnections;
mixin DEFINE_GUID!("CLSID_NetworkConnections", "7007ACC7-3202-11D1-AAD2-00805FC1270E");

//extern extern(C) const CLSID CLSID_NamespaceTreeControl;
mixin DEFINE_GUID!("CLSID_NamespaceTreeControl", "AE054212-3535-4430-83ED-D501AA6680E6");

//extern extern(C) const CLSID CLSID_IENamespaceTreeControl;
mixin DEFINE_GUID!("CLSID_IENamespaceTreeControl", "ACE52D03-E5CD-4b20-82FF-E71B11BEAE1D");

//extern extern(C) const CLSID CLSID_ScheduledTasks;
mixin DEFINE_GUID!("CLSID_ScheduledTasks", "D6277990-4C6A-11CF-8D87-00AA0060F5BF");

//extern extern(C) const CLSID CLSID_ApplicationAssociationRegistration;
mixin DEFINE_GUID!("CLSID_ApplicationAssociationRegistration", "591209c7-767b-42b2-9fba-44ee4615f2c7");

//extern extern(C) const CLSID CLSID_ApplicationAssociationRegistrationUI;
mixin DEFINE_GUID!("CLSID_ApplicationAssociationRegistrationUI", "1968106d-f3b5-44cf-890e-116fcb9ecef1");

//extern extern(C) const CLSID CLSID_SearchFolderItemFactory;
mixin DEFINE_GUID!("CLSID_SearchFolderItemFactory", "14010e02-bbbd-41f0-88e3-eda371216584");

//extern extern(C) const CLSID CLSID_OpenControlPanel;
mixin DEFINE_GUID!("CLSID_OpenControlPanel", "06622D85-6856-4460-8DE1-A81921B41C4B");

//extern extern(C) const CLSID CLSID_MailRecipient;
mixin DEFINE_GUID!("CLSID_MailRecipient", "9E56BE60-C50F-11CF-9A2C-00A0C90A90CE");

//extern extern(C) const CLSID CLSID_NetworkExplorerFolder;
mixin DEFINE_GUID!("CLSID_NetworkExplorerFolder", "F02C1A0D-BE21-4350-88B0-7367FC96EF3C");

//extern extern(C) const CLSID CLSID_DestinationList;
mixin DEFINE_GUID!("CLSID_DestinationList", "77f10cf0-3db5-4966-b520-b7c54fd35ed6");

//extern extern(C) const CLSID CLSID_ApplicationDestinations;
mixin DEFINE_GUID!("CLSID_ApplicationDestinations", "86c14003-4d6b-4ef3-a7b4-0506663b2e68");

//extern extern(C) const CLSID CLSID_ApplicationDocumentLists;
mixin DEFINE_GUID!("CLSID_ApplicationDocumentLists", "86bec222-30f2-47e0-9f25-60d11cd75c28");

//extern extern(C) const CLSID CLSID_HomeGroup;
mixin DEFINE_GUID!("CLSID_HomeGroup", "DE77BA04-3C92-4d11-A1A5-42352A53E0E3");

//extern extern(C) const CLSID CLSID_ShellLibrary;
mixin DEFINE_GUID!("CLSID_ShellLibrary", "d9b3211d-e57f-4426-aaef-30a806add397");

//extern extern(C) const CLSID CLSID_AppStartupLink;
mixin DEFINE_GUID!("CLSID_AppStartupLink", "273eb5e7-88b0-4843-bfef-e2c81d43aae5");

//extern extern(C) const CLSID CLSID_EnumerableObjectCollection;
mixin DEFINE_GUID!("CLSID_EnumerableObjectCollection", "2d3468c1-36a7-43b6-ac24-d3f02fd9607a");

//extern extern(C) const CLSID CLSID_DesktopGadget;
mixin DEFINE_GUID!("CLSID_DesktopGadget", "924ccc1b-6562-4c85-8657-d177925222b6");

static if(NTDDI_VERSION >= NTDDI_VISTA){
	export extern(Windows){
		HRESULT SHGetTemporaryPropertyForItem(IShellItem psi, REFPROPERTYKEY propkey, PROPVARIANT* ppropvar);
		HRESULT SHSetTemporaryPropertyForItem(IShellItem psi, REFPROPERTYKEY propkey, REFPROPVARIANT propvar);
	}
}

//(NTDDI_VERSION >= NTDDI_WIN7)
	//(_WIN32_IE >= _WIN32_IE_IE70)
		enum {
			LMD_DEFAULT                          = 0,
			LMD_ALLOWUNINDEXABLENETWORKLOCATIONS = 0x1
		}
		alias int LIBRARYMANAGEDIALOGOPTIONS;

static if((NTDDI_VERSION >= NTDDI_WIN7) && (_WIN32_IE >= _WIN32_IE_IE70)){
	export extern(Windows){
		HRESULT SHShowManageLibraryUI(IShellItem psiLibrary, HWND hwndOwner, LPCWSTR pszTitle, LPCWSTR pszInstruction, LIBRARYMANAGEDIALOGOPTIONS lmdOptions);
		HRESULT SHResolveLibrary(IShellItem psiLibrary);
	}
}

		HRESULT SHCreateLibrary(REFIID riid, void** ppv)
		{
			return CoCreateInstance(&CLSID_ShellLibrary, null, CLSCTX_INPROC_SERVER, riid, ppv);
		}

		HRESULT SHLoadLibraryFromItem(IShellItem psiLibrary, DWORD grfMode, REFIID riid, void** ppv)
		{
			*ppv = null;
			IShellLibrary plib;
			HRESULT hr = CoCreateInstance(&CLSID_ShellLibrary, null, CLSCTX_INPROC_SERVER, &IID_IShellLibrary, cast(void**)&plib);
			if(SUCCEEDED(hr)){
				hr = plib.LoadLibraryFromItem(psiLibrary, grfMode);
				if(SUCCEEDED(hr)){
					hr = plib.QueryInterface(riid, ppv);
				}
				plib.Release();
			}
			return hr;
		}

		HRESULT SHLoadLibraryFromKnownFolder(REFKNOWNFOLDERID kfidLibrary, DWORD grfMode, REFIID riid, void** ppv)
		{
			*ppv = null;
			IShellLibrary plib;
			HRESULT hr = CoCreateInstance(&CLSID_ShellLibrary, null, CLSCTX_INPROC_SERVER, &IID_IShellLibrary, cast(void**)&plib);
			if(SUCCEEDED(hr)){
				hr = plib.LoadLibraryFromKnownFolder(kfidLibrary, grfMode);
				if(SUCCEEDED(hr)){
					hr = plib.QueryInterface(riid, ppv);
				}
				plib.Release();
			}
			return hr;
		}

		HRESULT SHLoadLibraryFromParsingName(PCWSTR pszParsingName, DWORD grfMode, REFIID riid, void** ppv)
		{
			*ppv = null;
			IShellItem psiLibrary;
			HRESULT hr = SHCreateItemFromParsingName(pszParsingName, null, &IID_IShellItem, cast(void**)&psiLibrary);
			if(SUCCEEDED(hr)){
				hr = SHLoadLibraryFromItem(psiLibrary, grfMode, riid, ppv);
				psiLibrary.Release();
			}
			return hr;
		}

		HRESULT SHAddFolderPathToLibrary(IShellLibrary plib, PCWSTR pszFolderPath)
		{
			IShellItem psiFolder;
			HRESULT hr = SHCreateItemFromParsingName(pszFolderPath, null, &IID_IShellItem, cast(void**)&psiFolder);
			if(SUCCEEDED(hr)){
				hr = plib.AddFolder(psiFolder);
			psiFolder.Release();
			}
			return hr;
		}

		HRESULT SHRemoveFolderPathFromLibrary(IShellLibrary plib, PCWSTR pszFolderPath)
		{
			PIDLIST_ABSOLUTE pidlFolder = SHSimpleIDListFromPath(pszFolderPath);
			HRESULT hr = pidlFolder ? S_OK : E_INVALIDARG;
			if(SUCCEEDED(hr)){
				IShellItem psiFolder;
				hr = SHCreateItemFromIDList(pidlFolder, &IID_IShellItem, cast(void**)&psiFolder);
				if(SUCCEEDED(hr)){
					hr = plib.RemoveFolder(psiFolder);
					psiFolder.Release();
				}
				CoTaskMemFree(pidlFolder);
			}
			return hr;
		}

		HRESULT SHResolveFolderPathInLibrary(IShellLibrary plib, PCWSTR pszFolderPath, DWORD dwTimeout, PWSTR* ppszResolvedPath)
		{
			*ppszResolvedPath = null;
			PIDLIST_ABSOLUTE pidlFolder = SHSimpleIDListFromPath(pszFolderPath);
			HRESULT hr = pidlFolder ? S_OK : E_INVALIDARG;
			if(SUCCEEDED(hr)){
				IShellItem psiFolder;
				hr = SHCreateItemFromIDList(pidlFolder, &IID_IShellItem, cast(void**)&psiFolder);
				if(SUCCEEDED(hr)){
					IShellItem psiResolved;
					hr = plib.ResolveFolder(psiFolder, dwTimeout, &IID_IShellItem, cast(void**)&psiResolved);
					if(SUCCEEDED(hr)){
						hr = psiResolved.GetDisplayName(SIGDN_DESKTOPABSOLUTEPARSING, ppszResolvedPath);
						psiResolved.Release();
					}
					psiFolder.Release();
				}
				CoTaskMemFree(pidlFolder);
			}
			return hr;
		}

		HRESULT SHSaveLibraryInFolderPath(IShellLibrary plib, PCWSTR pszFolderPath, PCWSTR pszLibraryName, LIBRARYSAVEFLAGS lsf, PWSTR* ppszSavedToPath)
		{
			if(ppszSavedToPath){
				*ppszSavedToPath = null;
			}

			IShellItem psiFolder;
			HRESULT hr = SHCreateItemFromParsingName(pszFolderPath, null, &IID_IShellItem, cast(void**)&psiFolder);
			if(SUCCEEDED(hr)){
				IShellItem psiSavedTo;
				hr = plib.Save(psiFolder, pszLibraryName, lsf, &psiSavedTo);
				if(SUCCEEDED(hr)){
					if(ppszSavedToPath){
						hr = psiSavedTo.GetDisplayName(SIGDN_DESKTOPABSOLUTEPARSING, ppszSavedToPath);
					}
					psiSavedTo.Release();
				}
				psiFolder.Release();
			}
			return hr;
		}

//(NTDDI_VERSION >= NTDDI_VISTA)
	//extern extern(C) const IID IID_IAssocHandlerInvoker;
	interface IAssocHandlerInvoker : IUnknown {
	public extern(Windows):
		HRESULT SupportsSelection();
		HRESULT Invoke();
	}
	mixin DEFINE_IID!(IAssocHandlerInvoker, "92218CAB-ECAA-4335-8133-807FD234C2EE");

	//extern extern(C) const IID IID_IAssocHandler;
	interface IAssocHandler : IUnknown {
	public extern(Windows):
		HRESULT GetName(LPWSTR* ppsz);
		HRESULT GetUIName(LPWSTR* ppsz);
		HRESULT GetIconLocation(LPWSTR* ppszPath, int* pIndex);
		HRESULT IsRecommended();
		HRESULT MakeDefault(LPCWSTR pszDescription);
		HRESULT Invoke(IDataObject pdo);
		HRESULT CreateInvoker(IDataObject pdo, IAssocHandlerInvoker* ppInvoker);
	}
	mixin DEFINE_IID!(IAssocHandler, "F04061AC-1659-4a3f-A954-775AA57FC083");

	//extern extern(C) const IID IID_IEnumAssocHandlers;
	interface IEnumAssocHandlers : IUnknown {
	public extern(Windows):
		HRESULT Next(ULONG celt, IAssocHandler* rgelt, ULONG* pceltFetched);
	}
	mixin DEFINE_IID!(IEnumAssocHandlers, "973810ae-9599-4b88-9e4d-6ee98c9552da");

	enum {
		ASSOC_FILTER_NONE        = 0,
		ASSOC_FILTER_RECOMMENDED = 0x1
	}
	alias int ASSOC_FILTER;

static if(NTDDI_VERSION >= NTDDI_WIN7){
	export extern(Windows){
		HRESULT SHAssocEnumHandlers(LPCWSTR pszExtra, ASSOC_FILTER afFilter, IEnumAssocHandlers* ppEnumHandler);
		HRESULT SHAssocEnumHandlersForProtocolByApplication(PCWSTR protocol, REFIID riid, void** enumHandlers);
	}
}

export extern(Windows){
	uint BSTR_UserSize(uint*, uint, BSTR*);
	ubyte* BSTR_UserMarshal(uint*, ubyte*, BSTR*);
	ubyte* BSTR_UserUnmarshal(uint*, ubyte*, BSTR*);
	void BSTR_UserFree(uint*, BSTR*);

	uint HACCEL_UserSize(uint*, uint, HACCEL*);
	ubyte* HACCEL_UserMarshal(uint*, ubyte*, HACCEL*);
	ubyte* HACCEL_UserUnmarshal(uint*, ubyte*, HACCEL*);
	void HACCEL_UserFree(uint*, HACCEL*);

	uint HBITMAP_UserSize(uint*, uint, HBITMAP*);
	ubyte* HBITMAP_UserMarshal(uint*, ubyte*, HBITMAP*);
	ubyte* HBITMAP_UserUnmarshal(uint*, ubyte*, HBITMAP*);
	void HBITMAP_UserFree(uint*, HBITMAP*);

	uint HGLOBAL_UserSize(uint*, uint, HGLOBAL*);
	ubyte* HGLOBAL_UserMarshal(uint*, ubyte*, HGLOBAL*);
	ubyte* HGLOBAL_UserUnmarshal(uint*, ubyte*, HGLOBAL*);
	void HGLOBAL_UserFree(uint*, HGLOBAL*);

	uint HICON_UserSize(uint*, uint, HICON*);
	ubyte* HICON_UserMarshal(uint*, ubyte*, HICON*);
	ubyte* HICON_UserUnmarshal(uint*, ubyte*, HICON*);
	void HICON_UserFree(uint*, HICON*);

	uint HMENU_UserSize(uint*, uint, HMENU*);
	ubyte* HMENU_UserMarshal(uint*, ubyte*, HMENU*);
	ubyte* HMENU_UserUnmarshal(uint*, ubyte*, HMENU*);
	void HMENU_UserFree(uint*, HMENU*);

	uint HWND_UserSize(uint*, uint, HWND*);
	ubyte* HWND_UserMarshal(uint*, ubyte*, HWND*);
	ubyte* HWND_UserUnmarshal(uint*, ubyte*, HWND*);
	void HWND_UserFree(uint*, HWND*);

	uint LPSAFEARRAY_UserSize(uint*, uint, LPSAFEARRAY*);
	ubyte* LPSAFEARRAY_UserMarshal(uint*, ubyte*, LPSAFEARRAY*);
	ubyte* LPSAFEARRAY_UserUnmarshal(uint*, ubyte*, LPSAFEARRAY*);
	void LPSAFEARRAY_UserFree(uint*, LPSAFEARRAY*);

	uint PCIDLIST_ABSOLUTE_UserSize(uint*, uint, PCIDLIST_ABSOLUTE*);
	ubyte* PCIDLIST_ABSOLUTE_UserMarshal(uint*, ubyte*, PCIDLIST_ABSOLUTE*);
	ubyte* PCIDLIST_ABSOLUTE_UserUnmarshal(uint*, ubyte*, PCIDLIST_ABSOLUTE*);
	void PCIDLIST_ABSOLUTE_UserFree(uint*, PCIDLIST_ABSOLUTE*);

	uint PCUIDLIST_RELATIVE_UserSize(uint*, uint, PCUIDLIST_RELATIVE*);
	ubyte* PCUIDLIST_RELATIVE_UserMarshal(uint*, ubyte*, PCUIDLIST_RELATIVE*);
	ubyte* PCUIDLIST_RELATIVE_UserUnmarshal(uint*, ubyte*, PCUIDLIST_RELATIVE*);
	void PCUIDLIST_RELATIVE_UserFree(uint*, PCUIDLIST_RELATIVE*);

	uint PCUITEMID_CHILD_UserSize(uint*, uint, PCUITEMID_CHILD*);
	ubyte* PCUITEMID_CHILD_UserMarshal(uint*, ubyte*, PCUITEMID_CHILD*);
	ubyte* PCUITEMID_CHILD_UserUnmarshal(uint*, ubyte*, PCUITEMID_CHILD*);
	void PCUITEMID_CHILD_UserFree(uint*, PCUITEMID_CHILD*);

	uint PIDLIST_ABSOLUTE_UserSize(uint*, uint, PIDLIST_ABSOLUTE*);
	ubyte* PIDLIST_ABSOLUTE_UserMarshal(uint*, ubyte*, PIDLIST_ABSOLUTE*);
	ubyte* PIDLIST_ABSOLUTE_UserUnmarshal(uint*, ubyte*, PIDLIST_ABSOLUTE*);
	void PIDLIST_ABSOLUTE_UserFree(uint*, PIDLIST_ABSOLUTE*);

	uint PIDLIST_RELATIVE_UserSize(uint*, uint, PIDLIST_RELATIVE*);
	ubyte* PIDLIST_RELATIVE_UserMarshal(uint*, ubyte*, PIDLIST_RELATIVE*);
	ubyte* PIDLIST_RELATIVE_UserUnmarshal(uint*, ubyte*, PIDLIST_RELATIVE*);
	void PIDLIST_RELATIVE_UserFree(uint*, PIDLIST_RELATIVE*);

	uint PITEMID_CHILD_UserSize(uint*, uint, PITEMID_CHILD*);
	ubyte* PITEMID_CHILD_UserMarshal(uint*, ubyte*, PITEMID_CHILD*);
	ubyte* PITEMID_CHILD_UserUnmarshal(uint*, ubyte*, PITEMID_CHILD*);
	void PITEMID_CHILD_UserFree(uint*, PITEMID_CHILD*);

	uint VARIANT_UserSize(uint*, uint, VARIANT*);
	ubyte* VARIANT_UserMarshal(uint*, ubyte*, VARIANT*);
	ubyte* VARIANT_UserUnmarshal(uint*, ubyte*, VARIANT*);
	void VARIANT_UserFree(uint*, VARIANT*);

	uint BSTR_UserSize64(uint*, uint, BSTR*);
	ubyte* BSTR_UserMarshal64(uint*, ubyte*, BSTR*);
	ubyte* BSTR_UserUnmarshal64(uint*, ubyte*, BSTR*);
	void BSTR_UserFree64(uint*, BSTR*);

	uint HACCEL_UserSize64(uint*, uint, HACCEL*);
	ubyte* HACCEL_UserMarshal64(uint*, ubyte*, HACCEL*);
	ubyte* HACCEL_UserUnmarshal64(uint*, ubyte*, HACCEL*);
	void HACCEL_UserFree64(uint*, HACCEL*);

	uint HBITMAP_UserSize64(uint*, uint, HBITMAP*);
	ubyte* HBITMAP_UserMarshal64(uint*, ubyte*, HBITMAP*);
	ubyte* HBITMAP_UserUnmarshal64(uint*, ubyte*, HBITMAP*);
	void HBITMAP_UserFree64(uint*, HBITMAP*);

	uint HGLOBAL_UserSize64(uint*, uint, HGLOBAL*);
	ubyte* HGLOBAL_UserMarshal64(uint*, ubyte*, HGLOBAL*);
	ubyte* HGLOBAL_UserUnmarshal64(uint*, ubyte*, HGLOBAL*);
	void HGLOBAL_UserFree64(uint*, HGLOBAL*);

	uint HICON_UserSize64(uint*, uint, HICON*);
	ubyte* HICON_UserMarshal64(uint*, ubyte*, HICON*);
	ubyte* HICON_UserUnmarshal64(uint*, ubyte*, HICON*);
	void HICON_UserFree64(uint*, HICON*);

	uint HMENU_UserSize64(uint*, uint, HMENU*);
	ubyte* HMENU_UserMarshal64(uint*, ubyte*, HMENU*);
	ubyte* HMENU_UserUnmarshal64(uint*, ubyte*, HMENU*);
	void HMENU_UserFree64(uint*, HMENU*);

	uint HWND_UserSize64(uint*, uint, HWND*);
	ubyte* HWND_UserMarshal64(uint*, ubyte*, HWND*);
	ubyte* HWND_UserUnmarshal64(uint*, ubyte*, HWND*);
	void HWND_UserFree64(uint*, HWND*);

	uint LPSAFEARRAY_UserSize64(uint*, uint, LPSAFEARRAY*);
	ubyte* LPSAFEARRAY_UserMarshal64(uint*, ubyte*, LPSAFEARRAY*);
	ubyte* LPSAFEARRAY_UserUnmarshal64(uint*, ubyte*, LPSAFEARRAY*);
	void LPSAFEARRAY_UserFree64(uint*, LPSAFEARRAY*);

	uint PCIDLIST_ABSOLUTE_UserSize64(uint*, uint, PCIDLIST_ABSOLUTE*);
	ubyte* PCIDLIST_ABSOLUTE_UserMarshal64(uint*, ubyte*, PCIDLIST_ABSOLUTE*);
	ubyte* PCIDLIST_ABSOLUTE_UserUnmarshal64(uint*, ubyte*, PCIDLIST_ABSOLUTE*);
	void PCIDLIST_ABSOLUTE_UserFree64(uint*, PCIDLIST_ABSOLUTE*);

	uint PCUIDLIST_RELATIVE_UserSize64(uint*, uint, PCUIDLIST_RELATIVE*);
	ubyte* PCUIDLIST_RELATIVE_UserMarshal64(uint*, ubyte*, PCUIDLIST_RELATIVE*);
	ubyte* PCUIDLIST_RELATIVE_UserUnmarshal64(uint*, ubyte*, PCUIDLIST_RELATIVE*);
	void PCUIDLIST_RELATIVE_UserFree64(uint*, PCUIDLIST_RELATIVE*);

	uint PCUITEMID_CHILD_UserSize64(uint*, uint, PCUITEMID_CHILD*);
	ubyte* PCUITEMID_CHILD_UserMarshal64(uint*, ubyte*, PCUITEMID_CHILD*);
	ubyte* PCUITEMID_CHILD_UserUnmarshal64(uint*, ubyte*, PCUITEMID_CHILD*);
	void PCUITEMID_CHILD_UserFree64(uint*, PCUITEMID_CHILD*);

	uint PIDLIST_ABSOLUTE_UserSize64(uint*, uint, PIDLIST_ABSOLUTE*);
	ubyte* PIDLIST_ABSOLUTE_UserMarshal64(uint*, ubyte*, PIDLIST_ABSOLUTE*);
	ubyte* PIDLIST_ABSOLUTE_UserUnmarshal64(uint*, ubyte*, PIDLIST_ABSOLUTE*);
	void PIDLIST_ABSOLUTE_UserFree64(uint*, PIDLIST_ABSOLUTE*);

	uint PIDLIST_RELATIVE_UserSize64(uint*, uint, PIDLIST_RELATIVE*);
	ubyte* PIDLIST_RELATIVE_UserMarshal64(uint*, ubyte*, PIDLIST_RELATIVE*);
	ubyte* PIDLIST_RELATIVE_UserUnmarshal64(uint*, ubyte*, PIDLIST_RELATIVE*);
	void PIDLIST_RELATIVE_UserFree64(uint*, PIDLIST_RELATIVE*);

	uint PITEMID_CHILD_UserSize64(uint*, uint, PITEMID_CHILD*);
	ubyte* PITEMID_CHILD_UserMarshal64(uint*, ubyte*, PITEMID_CHILD*);
	ubyte* PITEMID_CHILD_UserUnmarshal64(uint*, ubyte*, PITEMID_CHILD*);
	void PITEMID_CHILD_UserFree64(uint*, PITEMID_CHILD*);

	uint VARIANT_UserSize64(uint*, uint, VARIANT*);
	ubyte* VARIANT_UserMarshal64(uint*, ubyte*, VARIANT*);
	ubyte* VARIANT_UserUnmarshal64(uint*, ubyte*, VARIANT*);
	void VARIANT_UserFree64(uint*, VARIANT*);
}

export extern(Windows){
	HRESULT IEnumIDList_Next_Proxy(IEnumIDList This, ULONG celt, PITEMID_CHILD* rgelt, ULONG* pceltFetched);
	HRESULT IEnumIDList_Next_Stub(IEnumIDList This, ULONG celt, PITEMID_CHILD* rgelt, ULONG* pceltFetched);
	HRESULT IEnumFullIDList_Next_Proxy(IEnumFullIDList This, ULONG celt, PIDLIST_ABSOLUTE* rgelt, ULONG* pceltFetched);
	HRESULT IEnumFullIDList_Next_Stub(IEnumFullIDList This, ULONG celt, PIDLIST_ABSOLUTE* rgelt, ULONG* pceltFetched);
	HRESULT IShellFolder_SetNameOf_Proxy(IShellFolder This, HWND hwnd, PCUITEMID_CHILD pidl, LPCWSTR pszName, SHGDNF uFlags, PITEMID_CHILD* ppidlOut);
	HRESULT IShellFolder_SetNameOf_Stub(IShellFolder This, HWND hwnd, PCUITEMID_CHILD pidl, LPCWSTR pszName, SHGDNF uFlags, PITEMID_CHILD* ppidlOut);
	HRESULT IFolderView2_GetGroupBy_Proxy(IFolderView2 This, PROPERTYKEY* pkey, BOOL* pfAscending);
	HRESULT IFolderView2_GetGroupBy_Stub(IFolderView2 This, PROPERTYKEY* pkey, BOOL* pfAscending);
	HRESULT IEnumShellItems_Next_Proxy(IEnumShellItems This, ULONG celt, IShellItem* rgelt, ULONG* pceltFetched);
	HRESULT IEnumShellItems_Next_Stub(IEnumShellItems This, ULONG celt, IShellItem* rgelt, ULONG* pceltFetched);
	HRESULT IParentAndItem_GetParentAndItem_Proxy(IParentAndItem This, PIDLIST_ABSOLUTE* ppidlParent, IShellFolder* ppsf, PITEMID_CHILD* ppidlChild);
	HRESULT IParentAndItem_GetParentAndItem_Stub(IParentAndItem This, PIDLIST_ABSOLUTE* ppidlParent, IShellFolder* ppsf, PITEMID_CHILD* ppidlChild);
	HRESULT IResultsFolder_AddIDList_Proxy(IResultsFolder This, PCIDLIST_ABSOLUTE pidl, PITEMID_CHILD* ppidlAdded);
	HRESULT IResultsFolder_AddIDList_Stub(IResultsFolder This, PCIDLIST_ABSOLUTE pidl, PITEMID_CHILD* ppidlAdded);
	HRESULT IEnumObjects_Next_Proxy(IEnumObjects This, ULONG celt, REFIID riid, void** rgelt, ULONG* pceltFetched);
	HRESULT IEnumObjects_Next_Stub(IEnumObjects This, ULONG celt, REFIID riid, void** rgelt, ULONG* pceltFetched);
	HRESULT IBandSite_QueryBand_Proxy(IBandSite This, DWORD dwBandID, IDeskBand* ppstb, DWORD* pdwState, LPWSTR pszName, int cchName);
	HRESULT IBandSite_QueryBand_Stub(IBandSite This, DWORD dwBandID, IDeskBand* ppstb, DWORD* pdwState, LPWSTR pszName, int cchName);
	HRESULT IModalWindow_Show_Proxy(IModalWindow This, HWND hwndOwner);
	HRESULT IModalWindow_Show_Stub(IModalWindow This, HWND hwndOwner);
	HRESULT IKnownFolderManager_Redirect_Proxy(IKnownFolderManager This, REFKNOWNFOLDERID rfid, HWND hwnd, KF_REDIRECT_FLAGS flags, LPCWSTR pszTargetPath, UINT cFolders, const(KNOWNFOLDERID)* pExclusion, LPWSTR* ppszError);
	HRESULT IKnownFolderManager_Redirect_Stub(IKnownFolderManager This, REFKNOWNFOLDERID rfid, HWND hwnd, KF_REDIRECT_FLAGS flags, LPCWSTR pszTargetPath, UINT cFolders, const(GUID)* pExclusion, LPWSTR* ppszError);
	HRESULT IEnumExplorerCommand_Next_Proxy(IEnumExplorerCommand This, ULONG celt, IExplorerCommand* pUICommand, ULONG* pceltFetched);
	HRESULT IEnumExplorerCommand_Next_Stub(IEnumExplorerCommand This, ULONG celt, IExplorerCommand* pUICommand, ULONG* pceltFetched);
}

} // extern(C)