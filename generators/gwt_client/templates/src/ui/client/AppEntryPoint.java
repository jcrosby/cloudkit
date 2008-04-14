package ui.client;

import com.google.gwt.core.client.EntryPoint;
import com.google.gwt.user.client.ui.Button;
import com.google.gwt.user.client.ui.ClickListener;
import com.google.gwt.user.client.ui.Label;
import com.google.gwt.user.client.ui.RootPanel;
import com.google.gwt.user.client.ui.Widget;

public class AppEntryPoint implements EntryPoint {

    public void onModuleLoad() {
        final Button button = new Button("Test");
        final Label label = new Label();

        button.addClickListener(new ClickListener() {
            public void onClick(Widget sender) {
                if (label.getText().equals(""))
                    label.setText("Your GWT setup works. Replace the EntryPoint code when ready.");
                } else {
                    label.setText("");
                }
            }
        });
        
        RootPanel.add(button);
        RootPanel.add(label);
    }
}
