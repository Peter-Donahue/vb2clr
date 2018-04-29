Attribute VB_Name = "ExitHandler"
' Copyright (C) 2018 jet
' For more information about license, see LICENSE.
'
' Helper module for handling on application-exit
Option Explicit

Private Type IID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
End Type

' �C���X�^���X�̃f�[�^
Private Type MyClassData
    vtblPtr As LongPtr
    RefCount As Long
#If Win64 Then ' 64�r�b�g�ł��ǂ���
    Padding As Long
#End If
End Type

' ���z�֐��e�[�u���̃f�[�^
Private Type IUnknownVtbl
    QueryInterface As LongPtr
    AddRef As LongPtr
    Release As LongPtr
End Type

Private Const S_OK As Long = 0
Private Const E_NOINTERFACE As Long = &H80004002
Private Const E_POINTER As Long = &H80004003

Private Declare PtrSafe Sub CopyMemory Lib "kernel32.dll" Alias "RtlMoveMemory" _
    (ByRef Destination As Any, ByRef Source As Any, ByVal Length As LongPtr)
Public Declare PtrSafe Function GetProcessHeap Lib "kernel32.dll" () As LongPtr
Public Declare PtrSafe Function HeapAlloc Lib "kernel32.dll" _
    (ByVal hHeap As LongPtr, ByVal dwFlags As Long, ByVal dwBytes As LongPtr) As LongPtr
Public Declare PtrSafe Function HeapFree Lib "kernel32.dll" _
    (ByVal hHeap As LongPtr, ByVal dwFlags As Long, ByVal lpMem As LongPtr) As Boolean

Public Declare PtrSafe Function CoTaskMemAlloc Lib "ole32.dll" _
    (ByVal cb As LongPtr) As LongPtr
Public Declare PtrSafe Sub CoTaskMemFree Lib "ole32.dll" _
    (ByVal pv As LongPtr)

' VBA���s���͎��O�C���X�^���X�����葱����ϐ�
Dim m_unk As IUnknown
Dim m_collHandlers As Collection

' �ϐ��Ɋ֐��A�h���X�������邽�߂ɗp����֐�
Private Function GetAddressOf(ByVal func As LongPtr) As LongPtr
    GetAddressOf = func
End Function

' MyClassData �� IUnknownVtbl �̃T�C�Y�����킹���f�[�^���w���|�C���^�[��Ԃ�
Private Function CreateInstanceMemory() As LongPtr
    Dim p As LongPtr, d As MyClassData, v As IUnknownVtbl
    ' MyClassData �� IUnknownVtbl �̃T�C�Y�����킹���f�[�^���쐬
    p = CoTaskMemAlloc(Len(d) + Len(v))
    If p <> 0 Then
        ' �ŏ��̎Q�ƃJ�E���g�͕K�� 1 �Ƃ���
        d.RefCount = 1
        ' MyClassData �̒���� IUnknownVtbl ��u���̂� p �� MyClassData �̃T�C�Y���������A�h���X���Z�b�g����
        d.vtblPtr = p + Len(d)
        ' ���蓖�Ă��������u���b�N�̐擪�� MyClassData �̃f�[�^�Ŗ��߂�
        Call CopyMemory(ByVal p, d, Len(d))
        ' ���z�֐��e�[�u���̍쐬
        v.QueryInterface = GetAddressOf(AddressOf My_QueryInterface)
        v.AddRef = GetAddressOf(AddressOf My_AddRef)
        v.Release = GetAddressOf(AddressOf My_Release)
        ' ���z�֐��e�[�u���� p + Len(d) �̕����ɃR�s�[
        Call CopyMemory(ByVal d.vtblPtr, v, Len(v))
    End If
    CreateInstanceMemory = p
End Function

' HRESULT STDMETHODCALLTYPE QueryInterface(THIS_ REFIID refiid, LPVOID FAR* ppv)
' �ʂ̃C���^�[�t�F�C�X�֕ϊ�����̂����N�G�X�g����Ƃ��ɌĂяo�����֐�
' (ppv �͔O�̂��� NULL �`�F�b�N�����邽�� ByVal �Œ�`)
Private Function My_QueryInterface(ByVal This As LongPtr, ByRef refiid As IID, ByVal ppv As LongPtr) As Long
    Debug.Print "My_QueryInterface"
    If ppv = 0 Then
        Debug.Print "  E_POINTER"
        My_QueryInterface = E_POINTER
        Exit Function
    End If
    ' IID_IUnknown: {00000000-0000-0000-C000-000000000046} ���ǂ����m�F
    If refiid.Data1 = 0 And refiid.Data2 = 0 And refiid.Data3 = 0 And _
        refiid.Data4(0) = &HC0 And refiid.Data4(1) = 0 And _
        refiid.Data4(2) = 0 And refiid.Data4(3) = 0 And _
        refiid.Data4(4) = 0 And refiid.Data4(5) = 0 And _
        refiid.Data4(6) = 0 And refiid.Data4(7) = 0 Then
        ' IID_IUnknown �̏ꍇ�� ppv ���w���|�C���^�[�̐�� This �̃A�h���X(This �̒l)���R�s�[
        Debug.Print "  IID_IUnknown"
        Call CopyMemory(ByVal ppv, This, Len(This))
        ' ����ɎQ�ƃJ�E���g�𑝂₷
        Call My_AddRef(This)
        My_QueryInterface = S_OK
        Exit Function
    End If
    ' IID_IUnknown �ȊO�̓T�|�[�g���Ȃ�
    Debug.Print "  E_NOINTERFACE"
    My_QueryInterface = E_NOINTERFACE
End Function

' ULONG STDMETHODCALLTYPE AddRef(THIS)
' �Q�ƃJ�E���g�𑝂₷�ۂɌĂяo�����֐�
Private Function My_AddRef(ByVal This As LongPtr) As Long
    Dim d As MyClassData
    ' �C���X�^���X�̃f�[�^����U d �ɃR�s�[���A
    ' �Q�ƃJ�E���g�𑝂₵���珑���߂�
    Call CopyMemory(d, ByVal This, Len(d))
    d.RefCount = d.RefCount + 1
    Debug.Print "My_AddRef: new RefCount ="; d.RefCount
    Call CopyMemory(ByVal This, d, Len(d))
    ' �߂�l�͎Q�ƃJ�E���g
    My_AddRef = d.RefCount
End Function

' ULONG STDMETHODCALLTYPE Release(THIS)
' �Q�ƃJ�E���g�����炷�ۂɌĂяo�����֐�(0 �ɂȂ�����j��)
Private Function My_Release(ByVal This As LongPtr) As Long
    Dim d As MyClassData
    ' �C���X�^���X�̃f�[�^����U d �ɃR�s�[���A
    ' �Q�ƃJ�E���g�����炵���珑���߂�
    Call CopyMemory(d, ByVal This, Len(d))
    d.RefCount = d.RefCount - 1
    Debug.Print "My_Release: new RefCount ="; d.RefCount
    Call CopyMemory(ByVal This, d, Len(d))
    ' �Q�ƃJ�E���g�� 0 �ɂȂ����� CoTaskMemFree �Ŕj������
    If d.RefCount = 0 Then
        Call CoTaskMemFree(This)
        ' �I���֐����Ăяo��
        Call OnExit
    End If
    ' �߂�l�͎Q�ƃJ�E���g
    My_Release = d.RefCount
End Function

' �I������ Handler.OnExit() ���Ăяo�����悤��
' Handler �I�u�W�F�N�g��o�^
Public Function AddExitHandler(ByVal Handler As Object, Optional ByVal Key As String) As Object
    Dim ptr As LongPtr
    If Not m_collHandlers Is Nothing Then
        On Error Resume Next
        Dim o As Object
        ptr = 0^
        ptr = m_collHandlers.Item(Key)
        On Error GoTo 0
        If ptr <> 0^ Then
            Call CopyMemory(o, ptr, Len(ptr))
            Set AddExitHandler = o
            ptr = 0^
            Call CopyMemory(o, ptr, Len(ptr))
            Exit Function
        End If
    End If
    If m_unk Is Nothing Then
        Dim p As LongPtr
        ' �C���X�^���X���쐬
        p = CreateInstanceMemory()
        If p = 0 Then Exit Function
        Dim unk As IUnknown
        ' unk �� p ���w���C���X�^���X�ɐݒ�
        Call CopyMemory(unk, p, Len(p))
        ' m_unk �ɃZ�b�g(������ My_AddRef ���Ăяo�����)
        Set m_unk = unk
        Set m_collHandlers = New Collection
    End If
    Call CopyMemory(ptr, Handler, Len(ptr))
    Call m_collHandlers.Add(ptr, Key)
    Set AddExitHandler = Handler
End Function

Public Sub RemoveExitHandler(ByVal Handler As Variant)
    If m_collHandlers Is Nothing Then Exit Sub
    If VarType(Handler) = vbString Then
        On Error Resume Next
        Call m_collHandlers.Remove(Handler)
        Exit Sub
    End If
    If VarType(Handler) <> vbObject And VarType(Handler) <> 13 Then
        Call Err.Raise(13)
    End If
    Dim ptr As LongPtr, i As Long
    On Error Resume Next
    For i = 1 To m_collHandlers.Count
        ptr = m_collHandlers.Item(i)
        If ptr = ObjPtr(Handler) Then
            Call m_collHandlers.Remove(i)
            Exit For
        End If
    Next i
End Sub

' VBA�I�����̏������L�q
Private Sub OnExit()
    Dim o As Object
    On Error Resume Next
    For Each o In m_collHandlers
        Call o.OnExit
    Next o
End Sub
