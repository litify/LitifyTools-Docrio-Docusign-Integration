@isTest
private with sharing class DocrioDocusignTest {

  private static SObject docuSignStatus;
  private static DocrioDocusignSettings__c apiSettings = DocrioDocusignSettings__c.getOrgDefaults();

  static {
      apiSettings.AWS_API_Prefix__c = '';
      apiSettings.AWS_Org_Info_API_Prefix__c = 'notempty';
      upsert apiSettings;

      docuSignStatus = DocrioDocusignTestUtil.createDocuSignStatus();
  }

  @isTest
  private static void testNewDocumentData_Success() {
      // test instantiation of DocumentData class
      Attachment document = DocrioDocusignTestUtil.createDSAttachment(true);
      String envelopeSourceObject = getEnvelopeSourceObject((String) docusignStatus.get('dsfs__DocuSign_Envelope_ID__c'));

      Test.startTest();
        DocrioDocusign.DocumentData docData = new DocrioDocusign.DocumentData(document.Name, envelopeSourceObject, document.Body);
      Test.stopTest();

    System.assertNotEquals(null, docData.fileData);
    System.assertNotEquals(null, docData.fileInfoRecord);

  }

  @isTest
  private static void testProcessSignedAttachment_Success() {
      // test Attachment record is processed without Exception
      Attachment document = DocrioDocusignTestUtil.createDSAttachment(true);

      Test.setMock(HttpCalloutMock.class, new CalloutSuccessResponseGenerator());
      Test.startTest();
      try {
        DocrioDocusign.processSignedAttachment(document.Id);
    } catch (Exception e) {
          System.assert(false);
      }
      Test.stopTest();
  }

  @isTest
  private static void testProcessSignedDocument_Success() {
      // test Document record is processed without Exception
      ContentDocumentLink document = DocrioDocusignTestUtil.createDSContentDoc(true);

      Test.setMock(HttpCalloutMock.class, new CalloutSuccessResponseGenerator());
      Test.startTest();
      try {
        DocrioDocusign.processSignedDocument(document.Id);
    } catch (Exception e) {
          System.assert(false);
      }
      Test.stopTest();
  }

  @isTest
  private static void testGetDocusignStatusRecordsAttach_Success() {
      // test docusign status record is returned if correct data
      Attachment document = DocrioDocusignTestUtil.createDSAttachment(true);

      Test.startTest();
          SObject statusRecord = DocrioDocusign.getDocusignStatusRecords(document.ParentId);
      Test.stopTest();

      System.assertNotEquals(null, statusRecord);
  }

  @isTest
  private static void testGetDocusignStatusRecordsDocument_Success() {
      // test docusign status record is not returned if incorrect data
      ContentDocumentLink document = DocrioDocusignTestUtil.createDSContentDoc(true);

      Test.startTest();
          SObject statusRecord = DocrioDocusign.getDocusignStatusRecords(document.LinkedEntityId);
      Test.stopTest();

      System.assertNotEquals(null, statusRecord);
  }

  @isTest
  private static void testGetDocusignStatusRecordsDocument_Fail() {
      // test docusign status record is not returned if incorrect data
      ContentDocumentLink document = DocrioDocusignTestUtil.createDSContentDoc(true);
      String badId = '';
      
      Test.startTest();
          SObject statusRecord = DocrioDocusign.getDocusignStatusRecords(badId);
      Test.stopTest();

      System.assertEquals(null, statusRecord);
  }

  @isTest
  private static void testSetOrgInfoPrefix_NoSetting_Success() {
      // test if API Prefix is NOT set we make (mock) API call to /orginfo to get it
      Test.setMock(HttpCalloutMock.class, new AwsApiPrefixTestSuccessResponseGenerator());

      Test.startTest();
          String orgInfoPrefix = DocrioDocusign.getOrgInfoUrl();
      Test.stopTest();

      System.assertEquals('TestUsedAPICallPrefixOrgInfo', orgInfoPrefix);
  }

  @isTest
  private static void testSetOrgInfoPrefix_WithSetting_Success() {
      // test if API Prefix IS set we use it
      apiSettings.AWS_API_Prefix__c = 'TestPrefixSettings';
      upsert apiSettings;

      Test.setMock(HttpCalloutMock.class, new AwsApiPrefixTestSuccessResponseGenerator());
      Test.startTest();
          String apiPrefix = DocrioDocusign.getOrgInfoUrl();
      Test.stopTest();

      System.assertEquals('TestPrefixSettings', apiPrefix);
  }

  @isTest
  private static void testSetOrgInfoPrefix_Exception() {
      // test correct exception type is thrown on org info Exception
      Test.setMock(HttpCalloutMock.class, new CalloutFailResponseGenerator());
      Test.startTest();
      try {
          String orgInfoPrefix = DocrioDocusign.getOrgInfoUrl();
      } catch (Exception e) {
          String excTypeName = e.getTypeName();
          System.assertEquals(true, excTypeName.contains('DocrioDocusignException'));
      }
      Test.stopTest();
  }

  @isTest
  private static void testGetAttachmentData_Success() {
      // test Attachment data is queried and collected
      Attachment att = DocrioDocusignTestUtil.createDSAttachment(true);
        
      Test.startTest();
       DocrioDocusign.DocumentData docData = 
           DocrioDocusign.getAttachmentData((String) docusignStatus.get('dsfs__DocuSign_Envelope_ID__c'), att);
      Test.stopTest();

    System.assertNotEquals(null, docData);
    System.assertEquals(att.Body, docData.fileData);
    System.assertEquals(att.Name, docData.fileInfoRecord.get('Name'));
  }

  @isTest
  private static void testGetContentDocData_Success() {
      // test ContentDocument records are queried and collected
      ContentDocumentLink contentDocLink = DocrioDocusignTestUtil.createDSContentDoc(true);
      String envelopeId = (String) docusignStatus.get('dsfs__DocuSign_Envelope_ID__c'); 
      Id contentDocId = (Id) contentDocLink.ContentDocumentId;
            List<ContentVersion> cvList = [
                SELECT Title, VersionData 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocId 
                AND IsLatest = true LIMIT 1
            ];

     ContentVersion cv = cvList[0];

      Test.startTest();
        DocrioDocusign.DocumentData docData = 
            DocrioDocusign.getContentDocumentData(envelopeId, cv);      
      Test.stopTest();
      
      System.assertNotEquals(null, docData);
      System.assertEquals(cv.VersionData, docData.fileData);
      System.assertEquals(cv.Title, docData.fileInfoRecord.get('Name'));
  }  

  @isTest
  private static void testStoreDocumentSuccess() { 
    // test storeDocument method succeeds with correct data
    Attachment att = DocrioDocusignTestUtil.createDSAttachment(true);   
    DocrioDocusign.DocumentData docData = 
            DocrioDocusign.getAttachmentData((String) docusignStatus.get('dsfs__DocuSign_Envelope_ID__c'), att);

      Test.setMock(HttpCalloutMock.class, new CalloutSuccessResponseGenerator());
      Test.startTest();
      try {
          DocrioDocusign.storeDocument(docData);
      } catch (Exception e) {
          System.assert(false);
      }
      Test.stopTest();
  }

  @isTest
  private static void testStoreDocumentCalloutFail() {
      // test correct exception type is thrown on store documents Exception
      Attachment att = DocrioDocusignTestUtil.createDSAttachment(true);   
      DocrioDocusign.DocumentData docData = 
              DocrioDocusign.getAttachmentData((String) docusignStatus.get('dsfs__DocuSign_Envelope_ID__c'), att);
  
      Test.setMock(HttpCalloutMock.class, new CalloutFailResponseGenerator());
      Test.startTest();
      try {
            DocrioDocusign.storeDocument(docData);
    } catch (Exception e) {
            String excTypeName = e.getTypeName();
            System.assertEquals(true, excTypeName.contains('DocrioDocusignException'));
      }
      Test.stopTest();
  }

  private static String getEnvelopeSourceObject(String envelopeId) {
    String sourceObject = '';
    List<SObject> envelopes = Database.query(
        'SELECT dsfs__Source_Object__c ' +
        'FROM dsfs__DocuSign_Envelope__c ' +
        'WHERE dsfs__DocuSign_Envelope_ID__c = :envelopeID ' +
        'LIMIT 1'
    );
    if (envelopes.size() > 0 ) { 
        sourceObject = (String) envelopes.get(0).get('dsfs__Source_Object__c');
    } 

    return sourceObject;
}

  private class AwsApiPrefixTestSuccessResponseGenerator implements HttpCalloutMock {
      public HttpResponse respond(HttpRequest request) {
          HttpResponse response = new HttpResponse();
          response.setHeader('Content-Type', 'application/json');
          response.setBody('{ "AwsApiPrefix": "TestUsedAPICallPrefixOrgInfo" }');
          response.setStatusCode(200);
          return response;
      }
  }

  private class CalloutSuccessResponseGenerator implements HttpCalloutMock {
      public HttpResponse respond(HttpRequest request) {
          HttpResponse response = new HttpResponse();
          response.setHeader('Content-Type', 'application/json');
          response.setBody('{ "TestFilename.pdf" : { "Id": "a1E1U000001juz6UAA", "SignedUrl": "testmock@testmock.com" } }');
          response.setStatusCode(200);
          return response;
      }
  }

  private class CalloutFailResponseGenerator implements HttpCalloutMock {
      public HttpResponse respond(HttpRequest request) {
          HttpResponse res = new HttpResponse();
          res.setHeader('Content-Type', 'application/json');
          res.setStatusCode(301);
          return res;
      }
  }
}