use ribbon_renderer::engine::RenderEngine;
use winit::{
    application::ApplicationHandler,
    event::WindowEvent,
    event_loop::{ActiveEventLoop, EventLoop},
    window::{Window, WindowId},
};

#[derive(Default)]
struct App {
    window: Option<&'static Window>,
    engine: Option<RenderEngine<'static>>,
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_none() {
            let window_attrs = Window::default_attributes()
                .with_title("Ribbon")
                .with_inner_size(winit::dpi::LogicalSize::new(1024.0, 768.0));

            let window = Box::leak(Box::new(event_loop.create_window(window_attrs).unwrap()));
            self.window = Some(window);

            let engine = pollster::block_on(RenderEngine::new(window))
                .expect("failed to initialize the render engine");
            self.engine = Some(engine);

            window.request_redraw();
        }
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        let Some(engine) = self.engine.as_mut() else {
            return;
        };
        let Some(window) = self.window else { return };

        match event {
            WindowEvent::CloseRequested => {
                event_loop.exit();
            }

            WindowEvent::Resized(physical_size) => {
                engine.resize(physical_size);
                window.request_redraw();
            }

            WindowEvent::RedrawRequested => {
                let (surface_texture, texture_view, mut encoder) = match engine.begin_frame() {
                    Ok(frame) => frame,
                    Err(e) => {
                        eprintln!("frame error: {:?}", e);
                        return;
                    }
                };

                {
                    let _render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                        label: Some("ribbon_clear_pass"),
                        color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                            view: &texture_view,
                            resolve_target: None,
                            ops: wgpu::Operations {
                                load: wgpu::LoadOp::Clear(wgpu::Color {
                                    r: 0.0,
                                    g: 0.0,
                                    b: 0.0,
                                    a: 255.0,
                                }),
                                store: wgpu::StoreOp::Store,
                            },
                            depth_slice: None,
                        })],
                        depth_stencil_attachment: None,
                        timestamp_writes: None,
                        occlusion_query_set: None,
                        multiview_mask: None,
                    });
                }

                engine.submit_frame(surface_texture, encoder);
            }
            _ => {}
        }
    }
}

fn main() {
    let event_loop = EventLoop::new().unwrap();
    event_loop.set_control_flow(winit::event_loop::ControlFlow::Wait);

    let mut app = App::default();

    event_loop.run_app(&mut app).unwrap();
}
