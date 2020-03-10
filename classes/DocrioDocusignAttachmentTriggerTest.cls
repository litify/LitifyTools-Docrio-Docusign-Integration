@isTest
private with sharing class DocrioDocusignAttachmentTriggerTest {

  @isTest
  private static void testTriggerCall_Success() {
      DocrioDocusignTestUtil.createDocuSignStatus();

      Test.startTest();
        DocrioDocusignTestUtil.createDSAttachment(false); 
      Test.stopTest();

      System.assertEquals(true, DocrioDocusign.triggerMadeCall);
  }

}