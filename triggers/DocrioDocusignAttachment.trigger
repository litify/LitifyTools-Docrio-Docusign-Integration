/**
* Trigger to initiate saving of newly signed/completed Docusign attachments to cloud storage with
* links to display in Litify docs applicaton.
* Attachments for a Docusign signing will be inserted individually
*/
trigger DocrioDocusignAttachment on Attachment (after insert) {
    if (DocrioDocusign.disableTriggers) { 
        return; 
    }
  
  for (Attachment att : trigger.New) {
      if (att.ParentId.getSobjectType().getDescribe().getName() == 'dsfs__DocuSign_Status__c') { 
          DocrioDocusign.processSignedAttachment(att.Id); 
      }
  }  
}