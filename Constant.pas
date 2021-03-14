unit Constant;

interface

const

// Edit Modes

  //EM_ADD            = 1;
  //EM_MODIFY         = 2;

// System

  START_UID         = 1000;
  START_GID         = 1000;
  COMPUTER_GROUP    = 65534; // nogroup

type
  TEditMode = (EM_ADD, EM_MODIFY);

resourcestring

// Search filters

  sANYCLASS     = '(objectclass=*)';
  sSAMBAACCNT   = '(objectclass=sambaAccount)';
  sPOSIXACCNT   = '(objectclass=posixAccount)';
  sGROUPS       = '(objectclass=posixGroup)';
  sMY_GROUP     = '(&(objectclass=posixGroup)(memberUid=%s))';
  sGROUPBYsGID  = '(&(objectclass=posixGroup)(gidNumber=%s))';
  sACCNTBYUID   = '(&(objectclass=posixAccount)(uid=%s))';

// Captions

  cDescription  = 'Description';
  cPickGroups   = 'Choose Groups';
  cPickAccounts = 'Choose Accounts';
  cNewResource  = 'New Resource';
  cEditResource = 'Edit Resource';
  cResource     = 'Resource:';
  cPropertiesOf = 'Properties of %s';
  cAddAddress   = 'Add Address';
  cEditAddress  = 'Edit Address';
  cSmtpAddress  = 'SMTP Address:';
  cConfirmDel   = 'Confirm';

// Messages

  stReqAttr      = 'Attribute %s may not be empty!';
  stReqNoEmpty   = '%s must have a value!';
  stReqMail      = 'At least one E-Mail address must be defined!';
  sPassDiff      = 'Passwords do not match!';
  sAccntNameReq  = 'Enter a name for this connection!';
  stGroupNameReq = 'Enter a name for this group!';
  stConfirmDel   = 'Do you want to delete entry "%s"?';
  stCntObjects   = '%d object(s) found.';

{// Captions

  cDescription  = 'Beschreibung';
  cPickGroups   = 'Gruppen ausw�hlen';
  cPickAccounts = 'Benutzer ausw�hlen';
  cNewResource  = 'Neue Resource';
  cEditResource = 'Resource Bearbeiten';
  cResource     = 'Resource:';
  cPropertiesOf = 'Eigenschaften von %s';
  cAddAddress   = 'Adresse Hinz�fugen';
  cEditAddress  = 'Adresse Bearbeiten';
  cSmtpAddress  = 'SMTP Adresse:';
  cConfirmDel   = 'L�schen von Eintr�gen best�tigen';

// Messages

  stReqAttr      = 'Attribute %s ist erforderlich!';
  stReqNoEmpty   = 'Eingabe erforderlich: %s!';
  stReqMail      = 'Es ist midestens eine E-Mail Adresse erforderlich!';
  sPassDiff      = 'Die eingegebene Kennw�rter sind unterschiedlich.';
  sAccntNameReq  = 'Bitte geben Sie einen Namen f�r diese Verbindung ein!';
  stGroupNameReq = 'Bitte geben Sie einen Namen f�r diese Gruppe ein!';
  stConfirmDel   = 'M�chten Sie Eintrag "%s" wirklich l�schen?';
  stCntObjects   = '%d Objekt(e) gefunden.';}

implementation

end.
