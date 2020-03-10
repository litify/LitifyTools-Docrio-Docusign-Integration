/**
* Trigger to initiate saving of newly signed/completed Docusign documents to cloud storage with
* links to display in Litify docs applicaton.
* Documents for a Docusign signing will be inserted individually.
*/
trigger DocrioDocusignContentDocument on ContentDocumentLink (after insert) {
    if (DocrioDocusign.disableTriggers) { 
        return; 
    }
  
    for (ContentDocumentLink cdl : trigger.New) {
        if (cdl.LinkedEntityId.getSobjectType().getDescribe().getName() == 'dsfs__DocuSign_Status__c') {
            DocrioDocusign.processSignedDocument(cdl.Id); 
        }
    }
}