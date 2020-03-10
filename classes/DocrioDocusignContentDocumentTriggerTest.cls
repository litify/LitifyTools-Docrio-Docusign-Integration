@isTest
private with sharing class DocrioDocusignContentDocumentTriggerTest {

  @isTest
  private static void testTriggerCall_Success() {
      DocrioDocusignTestUtil.createDocuSignStatus();

      Test.startTest();
        DocrioDocusignTestUtil.createDSContentDoc(false);
      Test.stopTest();
      
      System.assertEquals(true, DocrioDocusign.triggerMadeCall);
  }

}