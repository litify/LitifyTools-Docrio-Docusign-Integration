/**
  * Handler class for collecting and saving documents signed using Docusign eSignature to 
  * Docrio cloud storage, accessible in File Viewer.
  */
 public with sharing class DocrioDocusign {

    public class DocrioDocusignException extends Exception {}

    private static String orgInfoUrl = ''; 
    private static DocrioDocusignSettings__c apiSettings = DocrioDocusignSettings__c.getOrgDefaults();

    @TestVisible 
    public static Boolean disableTriggers = false;
    @TestVisible 
    public static Boolean triggerMadeCall = false;

    private static final String SESSION_ID = UserInfo.getSessionId(); 
    private static final String ENDPOINT_GET_ORGINFO = '/v1/orginfo'; 
    private static final String ENDPOINT_POST_FILES = '/v1/files'; 
    private static final String ENDPOINT_POST_FILESCOMPLETE = '/v1/files/complete'; 

    /**
     * Data class for encapsulating callout information.
     */
    @TestVisible
    private class DocumentData {
        public Map<String, String> fileInfoRecord;
        public Blob fileData;
        @TestVisible
        DocumentData(String docName, String envelopeSource, Blob filedata) {
            this.fileInfoRecord = new Map<String, String>{
                'Name'=> docName, 
                'litify_docs__Related_To__c'=> envelopeSource, 
                'litify_docs__Document_Category__c'=> 'Signed Documents', 
                'litify_docs__File_Type__c'=> 'application/pdf', 
                'litify_docs__Related_To_Api_Name__c'=> ((Id)envelopeSource).getSObjectType().getDescribe().getName()
            };
        this.fileData = fileData;
        }
    }

    /**
     * Control method for managing Attachment collection, saving, and error handling.
     */
    @future(callout=true)
    @TestVisible
    public static void processSignedAttachment(String attachmentId) {
        if (Test.isRunningTest()) {
            DocrioDocusign.triggerMadeCall = true; 
        }
        try {
            List<Attachment> attachments = [
                SELECT Id, Name, ParentId, Body 
                FROM Attachment 
                WHERE Id = :attachmentId LIMIT 1
            ];                     
            Attachment attach = attachments[0]; 
            SObject status = getDocusignStatusRecords(attach.ParentId);
            if (status == null) { 
                return; 
            }

            if (apiSettings.Id == null) { 
                throw new DocrioDocusignException('No API callout settings URL');
            }

            DocumentData docData = getAttachmentData((String) status.get('dsfs__DocuSign_Envelope_ID__c'), attach);
            orgInfoUrl = getOrgInfoUrl(); 
            storeDocument(docData);
            upsert apiSettings;

        } catch (Exception e) { // unit test could check for record!
            SObject docError = ((SObject)Type.forName('litify_docs__File_Error__c').newInstance()).getSObjectType().newSObject();
            docError.put('litify_docs__Error__c', e.getMessage());
            docError.put('litify_docs__Stack_Trace_String__c', e.getStackTraceString());
            docError.put('litify_docs__User__c', UserInfo.getUserId());
            System.debug('Exception: '+ e);
            insert docError;
        }               
    }

    /**
     * Control method for managing Content Document collection, saving, and error handling.
     */
    @future(callout=true)
    @TestVisible
    public static void processSignedDocument(String documentId) {
        if (Test.isRunningTest()) {
            DocrioDocusign.triggerMadeCall = true; 
        }
        try {
            List<ContentDocumentLink> cdls = [
                SELECT Id, LinkedEntityId, ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE Id = :documentId LIMIT 1
            ];                     
            ContentDocumentLink contentDocLink = cdls[0];
            
            SObject status = getDocusignStatusRecords(contentDocLink.LinkedEntityId);
            if (status == null) { 
                return; 
            }

            if (apiSettings.Id == null) { 
                throw new DocrioDocusignException('No API callout settings URL');
            }

            Id contentDocId = (Id)contentDocLink.ContentDocumentId;
            List<ContentVersion> cvList = [
                SELECT Title, VersionData 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocId 
                AND IsLatest = true LIMIT 1
            ];

            DocumentData docData = getContentDocumentData((String) status.get('dsfs__DocuSign_Envelope_ID__c'), cvList[0]);
            orgInfoUrl = getOrgInfoUrl(); 
            storeDocument(docData);
            upsert apiSettings;

        } catch (Exception e) {
            SObject docError = ((SObject)Type.forName('litify_docs__File_Error__c').newInstance()).getSObjectType().newSObject();
            docError.put('litify_docs__Error__c', e.getMessage());
            docError.put('litify_docs__Stack_Trace_String__c', e.getStackTraceString());
            docError.put('litify_docs__User__c', UserInfo.getUserId());
            System.debug('Exception: '+ e);
            insert docError;
        }
    }

     /**
     * Utility method to query and return Docusign Status record given parent Id.
     */
    @TestVisible
    private static SObject getDocusignStatusRecords(String parentId) {
        SObject statusRecord = null;
        List<SObject> statuses = Database.query(
            'SELECT Id, dsfs__DocuSign_Envelope_ID__c ' +
            'FROM dsfs__DocuSign_Status__c ' +
            'WHERE dsfs__Envelope_Status__c = \'Completed\' ' +
            'AND Id = :parentId LIMIT 1'
        ); 
        if (statuses.size() > 0) {
            statusRecord = statuses[0];
        }

        return statusRecord;
    }

     /**
     * Utility method to instantiate and return DocumentData object given envelope Id and Attachment.
     */
    @TestVisible
    private static DocumentData getAttachmentData(String envelopeId, Attachment attach) {
        String envelopeSourceObject = getEnvelopeSourceObject(envelopeId);
        DocumentData docData = new DocumentData(attach.Name, envelopeSourceObject, attach.Body); 
        if (docData == null) {
            throw new DocrioDocusignException('No attachments found');
        }
        return DocData;
    }

    /**
     * Utility method to instantiate and return DocumentData object given envelope Id and ContentVersion.
     */
    @TestVisible
    private static DocumentData getContentDocumentData(String envelopeId, ContentVersion cv) {
        String envelopeSourceObject = getEnvelopeSourceObject(envelopeId);
        DocumentData docData = new DocumentData(cv.Title, envelopeSourceObject, cv.VersionData);
        if (docData == null) {
            throw new DocrioDocusignException('No content documents found');
        }
        return docData;
    }

    /**
     * Utility method to query and return Source object (parent of envelopee) given envelope Id.
     */
    @TestVisible
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

    /**
     * Utility method to callout and return Org Info.
     */
    @TestVisible
    private static String getOrgInfoUrl() {     
        String apiUrl = apiSettings.AWS_API_Prefix__c;     
        if (String.isBlank(apiUrl)) {
            String settingsUrl = apiSettings.AWS_Org_Info_API_Prefix__c;
            Map<String,Object> orgInfoMap = new Map<String, Object>();

            if (String.isNotBlank(settingsUrl)) { 
                HTTPResponse res = makeApiCallout(null, settingsUrl+ENDPOINT_GET_ORGINFO, 'GET', true, 'json', null);

                orgInfoMap = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                apiSettings.AWS_API_Prefix__c = (String)orgInfoMap.get('AwsApiPrefix'); // set for later update
            }
            apiUrl = (String)orgInfoMap.get('AwsApiPrefix');

            } 
        return apiUrl;
    }

    /**
     * Control method to make API callouts for saving documents.
     */
    @TestVisible
    private static void storeDocument(DocumentData docData) { 
        List<Id> fileInfoIds = new List<Id>();
        HttpResponse res = makeApiCallout(JSON.serialize(new List<Map<String, String>>{docData.fileInfoRecord}), orgInfoUrl+ENDPOINT_POST_FILES, 'POST', true, 'json', null);

        Map<String,Object> resMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        for (String fileName : resMap.keySet()) { // loop response for id & url specific to each body
            Map<String, Object> fileMap = (Map<String, Object>)resMap.get(fileName);
            fileInfoIds.add((Id) fileMap.get('Id'));
            String postedFilesSignedUrl = (String)fileMap.get('SignedUrl');  
            makeApiCallout(null, postedFilesSignedUrl, 'PUT', false, 'pdf', docData.fileData); 
            
            Map<String, Object> filesInfoMap = new Map<String, Object>{'Ids'=> fileInfoIds}; 
            makeApiCallout(JSON.serialize(filesInfoMap), orgInfoUrl+ENDPOINT_POST_FILESCOMPLETE, 'POST', true, 'json', null);
        }
    }

    /**
     * Utility method for common HttpRequest HttpResponse calls.
     * Throws Exception on failed status code.
     */
    private static HTTPResponse makeApiCallout(String body, String endPoint, String method, Boolean isAuth, String type, Blob bodyBlob) {
        HttpRequest req = new HttpRequest();
        req.setHeader('Content-Type', 'application/' + type);
        req.setTimeout(120000);
        req.setEndpoint(endPoint); 
        req.setMethod(method);
        if (isAuth) {
            req.setHeader('Authorization', 'Bearer ' + SESSION_ID);
        }
        if (body != null) {
            req.setBody(body);
        }
        if (bodyBlob != null) {
            req.setBodyAsBlob(bodyBlob);
        }
        Http http = new Http();
        HttPResponse res = http.send(req);

        if (res.getStatusCode() >= 300) {
            throw new DocrioDocusignException(res.getBody());
        }
        return res;
    }

}