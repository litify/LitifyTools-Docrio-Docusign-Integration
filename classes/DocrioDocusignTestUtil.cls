@isTest
public with sharing class DocrioDocusignTestUtil {

  public static Attachment createDSAttachment(Boolean disableTriggers) {
      if (disableTriggers) { 
          DocrioDocusign.disableTriggers = true; 
      }
      SObject docuSignStatus = createDocuSignStatus();
      Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');
      Attachment attach = new Attachment(  
          Name ='Unit Test Attachment',
          body = bodyBlob,
          parentId = (Id) docuSignStatus.get('Id')); 
      insert attach;
      return attach;
  }

  public static ContentDocumentLink createDSContentDoc(Boolean disableTriggers) {
      if (disableTriggers) { 
          DocrioDocusign.disableTriggers = true; 
      }
      SObject docuSignStatus = createDocuSignStatus();
      ContentVersion cv = new ContentVersion( 
          title = 'Unit Test CV Title',     
          PathOnClient ='test',          
          VersionData = Blob.valueOf('Unit Test Attachment Body'));        
      insert cv; 
      
      List<ContentDocument> documents = [
          SELECT Id, Title, LatestPublishedVersionId 
          FROM ContentDocument
      ];

      ContentDocumentLink cdl = New ContentDocumentLink();
      cdl.LinkedEntityId = (Id) docuSignStatus.get('Id');
      cdl.ContentDocumentId = documents[0].Id;
      cdl.shareType = 'V';
      insert cdl;
      return cdl;
  }

 public static SObject createDocuSignStatus() {
      SObject a = ((SObject)Type.forName('Account').newInstance()).getSObjectType().newSObject();
      a.put('litify_pm__Last_Name__c', 'Test Account');
      insert a;

      SObject o = ((SObject)Type.forName('Opportunity').newInstance()).getSObjectType().newSObject();
      o.put('Name', 'Test Opp');
      o.put('CloseDate', System.today());
      o.put('AccountId', (Id) a.get('Id'));
      o.put('StageName', 'Signed / Closed Sale');
      o.put('Amount', Decimal.valueOf('6995'));
      insert o;

      SObject matter = ((SObject)Type.forName('litify_pm__Matter__c').newInstance()).getSObjectType().newSObject();
      matter.put('litify_pm__Client__c', (Id) a.get('Id'));
      insert matter;

      SObject envelope = ((SObject)Type.forName('dsfs__DocuSign_Envelope__c').newInstance()).getSObjectType().newSObject();
      envelope.put('dsfs__DocuSign_Envelope_ID__c', '360a4d92-49f8-4002-9028-4ea9d7cecb81');
      envelope.put('dsfs__Source_Object__c', (Id) matter.get('Id'));
      insert envelope;

      SObject dsfs = ((SObject)Type.forName('dsfs__DocuSign_Status__c').newInstance()).getSObjectType().newSObject();
      dsfs.put('dsfs__Company__c', (Id) o.get('AccountId'));
      dsfs.put('dsfs__Opportunity__c', (Id) o.get('Id'));
      dsfs.put('dsfs__Envelope_Status__c', 'Completed');
      dsfs.put('dsfs__DocuSign_Envelope_ID__c', '360a4d92-49f8-4002-9028-4ea9d7cecb81');
      dsfs.put('dsfs__Subject__c', 'Document for eSignature');
      insert dsfs;  // only 'Completed' status meets trigger condition

      return dsfs;
  }  

}