object HostDlg: THostDlg
  Left = 371
  Top = 202
  BorderStyle = bsDialog
  Caption = 'Create host'
  ClientHeight = 407
  ClientWidth = 404
  Color = clBtnFace
  ParentFont = True
  OldCreateOrder = True
  Position = poMainFormCenter
  OnClose = FormClose
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object NameLabel: TLabel
    Left = 16
    Top = 16
    Width = 55
    Height = 13
    Caption = '&Host name:'
  end
  object IPLabel: TLabel
    Left = 16
    Top = 64
    Width = 56
    Height = 13
    Caption = 'IP &Address:'
  end
  object Label2: TLabel
    Left = 16
    Top = 112
    Width = 57
    Height = 13
    Caption = '&Description:'
  end
  object cn: TEdit
    Left = 16
    Top = 32
    Width = 369
    Height = 21
    TabOrder = 0
  end
  object GroupBox1: TGroupBox
    Left = 16
    Top = 160
    Width = 369
    Height = 201
    Caption = ' Additional host &names: '
    TabOrder = 3
    object cnList: TListBox
      Left = 8
      Top = 16
      Width = 353
      Height = 145
      ItemHeight = 13
      TabOrder = 0
      OnClick = cnListClick
    end
    object AddHostBtn: TButton
      Left = 8
      Top = 168
      Width = 65
      Height = 25
      Caption = '&Add'
      TabOrder = 1
      OnClick = AddHostBtnClick
    end
    object EditHostBtn: TButton
      Left = 80
      Top = 168
      Width = 65
      Height = 25
      Caption = '&Edit'
      Enabled = False
      TabOrder = 2
      OnClick = EditHostBtnClick
    end
    object DelHostBtn: TButton
      Left = 152
      Top = 168
      Width = 65
      Height = 25
      Caption = '&Remove'
      Enabled = False
      TabOrder = 3
      OnClick = DelHostBtnClick
    end
  end
  object OKBtn: TButton
    Left = 136
    Top = 368
    Width = 75
    Height = 25
    Caption = '&OK'
    Default = True
    ModalResult = 1
    TabOrder = 4
  end
  object CancelBtn: TButton
    Left = 216
    Top = 368
    Width = 75
    Height = 25
    Cancel = True
    Caption = '&Cancel'
    ModalResult = 2
    TabOrder = 5
  end
  object ipHostNumber: TEdit
    Left = 16
    Top = 80
    Width = 369
    Height = 21
    TabOrder = 1
    OnChange = EditChange
  end
  object description: TEdit
    Left = 16
    Top = 128
    Width = 369
    Height = 21
    TabOrder = 2
    OnChange = EditChange
  end
end
